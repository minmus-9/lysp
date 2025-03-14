;; lisp.lisp - runtime for lisp.py
;;
;; lysp - python lisp: solution in search of a problem
;;       https://github.com/minmus-9/lysp
;; Copyright (C) 2025  Mark Hays (github:minmus-9)
;; 
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; {{{ basics

;; to accompany quasiquote
(define (unquote x) (error "cannot unquote here"))
(define (unquote-splicing x) (error "cannot unquote-splicing here"))

;; used everywhere
(define (pair? x) (eq? (type x) 'pair))
(define (list & args) args)

;; ditto
(define (cadr l) (car (cdr l)))
(define (caddr l) (car (cdr (cdr l))))
(define (cadddr l) (car (cdr (cdr (cdr l)))))
(define (caddddr l) (car (cdr (cdr (cdr (cdr l))))))

;; }}}
;; {{{ foreach
;; call f for each element of lst, returns ()

(define (foreach f lst)
    (if
        (null? lst)
        ()
        (begin
            (f (car lst))
            (foreach f (cdr lst))
        )
    )
)

;; }}}
;; {{{ last

(define (last lst)
    (if
        (null? lst)
        ()
        (if
            (null? (cdr lst))
            (car lst)
            (last (cdr lst))
        )
    )
)

;; }}}
;; {{{ bitwise ops

;; bitwise ops from nand
(define (~ x)   (nand x x))
(define (& x y) (~ (nand x y)))
(define (| x y) (nand (~ x) (~ y)))
(define (^ x y) (& (nand x y) (| x y)))

;; }}}
;; {{{ arithmetic

(define (+ x y) (- x (- y)))

;; oh, mod
(define (% n d) (- n (* d (/ n d))))

;; absolute value
(define (abs x)
    (if
        (< x 0)
        (- x)
        x
    )
)

;; copysign
(define (copysign x y)
    (if
        (< y 0)
        (- (abs x))
        (abs x)
    )
)

;; unsigned shifts
(define (lshift x n)
    (if
        (equal? n 0)
        x
        (lshift (+ x x) (- n 1))
    )
)

(define (rshift x n)
    (if
        (equal? n 0)
        x
        (rshift (/ x 2) (- n 1))
    )
)

;; }}}
;; {{{ comparison predicates

(define (>= x y) (not (< x y)))
(define (>  x y) (< y x))
(define (<= x y) (not (< y x)))

;; }}}
;; {{{ and or not

(special (and & __special_and_args__)
    (eval (and$ __special_and_args__) 1))

(define (and$ __special_and_args__)
    (if
        (null? __special_and_args__)
        ()
        `(begin
            (define __special_and_v__ ,(car __special_and_args__))
            (if
                (null? ',(cdr __special_and_args__))
                __special_and_v__
                (if
                    __special_and_v__
                    ,(and$ (cdr __special_and_args__))
                    ()
                )
            )
        )
    )
)

(special (or & __special_or_args__)
    (eval (or$ __special_or_args__) 1))

(define (or$ __special_or_args__)
    (if
        (null? __special_or_args__)
        ()
        `(begin
            (define __special_or_v__ ,(car __special_or_args__))
            (if
                __special_or_v__
                __special_or_v__
                ,(or$ (cdr __special_or_args__))
            )
        )
    )
)

(define not null?)

;; }}}
;; {{{ assert

(special (assert __special_assert_sexpr__)
    (if
        (eval __special_assert_sexpr__)
        ()
        (error (obj>string __special_assert_sexpr__))
    )
)

;; }}}
;; {{{ reverse

(define (reverse l)
    (define (rev x y)
        (if
            (null? x)
            y
            (rev (cdr x) (cons (car x) y))
        )
    )
    (rev l ())
)

;; }}}
;; {{{ length

(define (length lst)
    (define (liter l i)
        (if (null? l) i (liter (cdr l) (- i -1))))
    (liter lst 0)
)

;; }}}
;; {{{ fold, transpose, map
;; sicp p.158-165 with interface tweaks
(define (fold-left f x sequence)
    (if 
        (null? sequence)
        x
        (fold-left f (f (car sequence) x) (cdr sequence))
    )
)

(define reduce fold-left)  ;; python nomenclature

(define (fold-right f initial sequence)
      (fold-left f initial (reverse sequence)))

(define accumulate fold-right)  ;; sicp nomenclature

;(fold-left  cons () (list 1 4 9))  ;; (9 4 1)    (cons 9 (cons 4 (cons 1 ())))
;(fold-right cons () (list 1 4 9))  ;; (1 4 9)    (cons 1 (cons 4 (cons 9 ())))

;; not elegant like sicp -- but faster in this lisp
(define (map1 f lst)
    (define ret ())  ;; head of queue and return value
    (define tail ())  ;; tail of queue
    (define (map1$ lst)
        (if
            (null? lst)
            ret
            (begin
                ;; link in the new value
                (set-cdr! tail (cons (f (car lst)) ()))
                (set! tail (cdr tail))
                ;; rinse, repeat
                (map1$ (cdr lst))
            )
        )
    )
    (if
        (null? lst)
        ()
        (begin
            ;; enqueue the first item here to avoid main loop test
            (set! ret (cons (f (car lst)) ()))
            (set! tail ret)
            (map1$ (cdr lst))
        )
    )
)

(define (accumulate-n f initial sequences)
    (define r ())
    (define c (call/cc))
    (if
        (null? (car sequences))
        (reverse r)
        (begin
            (set! r (cons (accumulate f initial (map1 car sequences)) r))
            (set! sequences (map1 cdr sequences))
            (c c)
        )
    )
)

(define (ftranspose f lists)
    (define ret ())  ;; head of queue and return value
    (define tail ())  ;; tail of queue
    (define (t1 lists)
        (if
            (null? (car lists))
            ret
            (begin
                ;; link in the new value
                (set-cdr! tail (cons (f (map1 car lists)) ()))
                (set! tail (cdr tail))
                ;; rinse, repeat
                (t1 (map1 cdr lists))
            )
        )
    )
    (if
        (null? (car lists))
        ()
        (begin
            ;; enqueue the first item here to avoid main loop test
            (set! ret (cons (f (map1 car lists)) ()))
            (set! tail ret)
            (t1 (map1 cdr lists))
        )
    )
)

(define (transpose lists)
    (ftranspose (lambda (x) x) lists))

(define (map f & lists)
    (ftranspose (lambda (tuple) (apply f tuple)) lists))

;; }}}
;; {{{ queue

(define (queue)
    (define (unpack0 args)
        (if args (error "too many args") ()))
    (define (unpack1 args)
        (if
            (null? args)
            (error "not enough args")
            ()
        )
        (if
            (null? (cdr args))
            (car args)
            (error "too many args")
        )
    )
    (define head ())
    (define tail ())
    (define node ())
    (define (enqueue x)
        (set! node (cons x ()))
        (if
            (null? head)
            (set! head node)
            (set-cdr! tail node)
        )
        (set! tail node)
    )
    (define (e lst)
        (if
            (null? lst)
            ()
            (begin
                (set-cdr! tail (cons (car lst) ()))
                (set! tail (cdr tail))
                (e (cdr lst))
            )
        )
    )
    (define (extend lst)
        (if
            (null? lst)
            ()
            (begin
                (enqueue (car lst))
                (e (cdr lst))
            )
        )
    )
    (define (dequeue)
        (define n head)
        (set! head (cdr n))
        (if
            (null? head)
            (set! tail ())
            ()
        )
        (car n)
    )
    (define (append x)
        (if
            (pair? x)
            (set-cdr! tail x)
            (error "can only append list")
        )
    )
    (define (dispatch m & args)
        (cond
            ((eq? m 'extend) (extend (unpack1 args)))
            ((eq? m 'enqueue) (enqueue (unpack1 args)))
            ((eq? m 'dequeue) (unpack0 args) (dequeue))
            ((eq? m 'get) (unpack0 args) head)
            ((eq? m 'depth) (unpack0 args) (length head))
            ((eq? m 'append) (append (unpack1 args)))
        )
    )
    dispatch
)

;; }}}
;; {{{ join

(define (join x & lists)
    (define q (queue))
    (define (j x lists)
        (if
            (null? lists)
            (begin
                (q 'append x)
                (q 'get)
            )
            (begin
                (q 'extend x)
                (j (car lists) (cdr lists))
            )
        )
    )
    (if (null? lists) x (j x lists))
)

;; }}}
;; {{{ let

(special (let __special_let_vdefs__ & __special_let_body__)
    (eval (let$ __special_let_vdefs__ __special_let_body__) 1))

(define (let$ vdefs body)
    (define vdecls (transpose vdefs))
    (define vars (car vdecls))
    (define vals (cadr vdecls))
    `((lambda (,@vars) ,@body) ,@vals)
)

;; }}}
;; {{{ let*

(special (let* __special_lets_vdefs__ & __special_lets_body__)
    (eval (let*$ __special_lets_vdefs__ __special_lets_body__) 1))

(define (let*$ vdefs body)
    (if
        (null? vdefs)
        (if
            (null? (cdr body))
            (car body)
            (cons 'begin body)
        )
        (begin
            (define kv (car vdefs))
            (define k (car kv))
            (define v (cadr kv))
          `((lambda (,k) ,(let*$ (cdr vdefs) body)) ,v)
        )
    )
)

;; }}}
;; {{{ letrec
;; i saw this (define x ()) ... (set! x value) on stackoverflow somewhere

(special (letrec __special_letrec_decls__ & __special_letrec_body__)
    (eval (letrec$ __special_letrec_decls__ __special_letrec_body__) 1))

(define (letrec$ decls body)
    (define names (map1 car decls))
    (define values (map1 cadr decls))
    (define (declare var) `(define ,var ()))
    (define (initialize var-value) `(set! ,(car var-value) ,(cadr var-value)))
    (define (declare-all) (map1 declare names))
    (define (initialize-all) (map1 initialize decls))
    `((lambda () (begin ,@(declare-all) ,@(initialize-all) ,@body)))
)

;; }}}
;; {{{ associative table

(define (table compare)
    (define items ())
    (define (dispatch m & args)
        (cond
            ((eq? m 'known) (not (null? (table$find items key compare))))
            ((eq? m 'del) (set! items (table$delete items (car args) compare)))
            ((eq? m 'get) (begin
                (let* (
                    (key (car args))
                    (node (table$find items key compare)))
                    (if
                        (null? node)
                        ()
                        (cadr node)
                    )
                )
            ))
            ((eq? m 'iter) (begin
                (let ((lst items))
                    (lambda ()
                        (if
                            (null? lst)
                            ()
                            (begin
                                (define ret (car lst))
                                (set! lst (cdr lst))
                                ret
                            )
                        )
                    )
                )
            ))
            ((eq? m 'len) (length items))
            ((eq? m 'raw) items)
            ((eq? m 'set) (begin
                (let* (
                    (key (car args))
                    (value (cadr args))
                    (node (table$find items key compare)))
                    (if
                        (null? node)
                        (begin
                            (let* (
                                (node (cons key (cons value ()))))
                                (set! items (cons node items)))
                        )
                        (set-car! (cdr node) value)
                    )
                )
            ))
            (#t (error "unknown method"))
        )
    )
    dispatch
)

(define (table$find items key compare)
    (cond
      ((null? items) ())
      ((compare (car (car items)) key) (car items))
      (#t (table$find (cdr items) key compare))
    )
)

(define (table$delete items key compare)
    (define prev ())
    (define (helper assoc key)
        (cond
            ((null? assoc) items)
            ((compare (car (car assoc)) key) (begin
                (cond
                    ((null? prev) (cdr assoc))
                    (#t (begin (set-cdr! prev (cdr assoc)) items))
                )
            ))
            (#t (begin
                (set! prev assoc)
                (helper (cdr assoc) key)
            ))
        )
    )
    (helper items key)
)

;; }}}
;; {{{ looping: loop, loop-with-break, for, while, while2

;; call f in a loop forever
(define (loop f) (f) (loop f))

(define (loop-with-break f)
    (define (break) (c ()))
    (define c (call/cc))
    (if
        c
        (begin
            (define c2 (call/cc))
            (f break)
            (c2 c2)
        )
        ()
    )
)

(define (while f) (if (f) (while f) ()))

;; call f a given number of times as (f counter)
(define (for f start stop step)
    (define (for$ f start)
        (if
            (< start stop)
            (begin
                (f start)
                (for$ f (- start (- 0 step)))
            )
            ()
        )
    )
    (if
        (< step 1)
        (error "step must be positive")
        (for$ f start)
    )
)


;; }}}
;; {{{ iterate (compose with itself) a function

(define (iter-func f x0 n)
    (if (< n 1) x0 (iter-func f (f x0) (- n 1)))
)

;; }}}
;; {{{ benchmarking

(define (timeit f n)
    (define (loop i)
        (if (< i n) (begin (f i) (loop (- i -1))) ()))
    (define t0 (time 'time))
    (loop 0)
    (define t1 (time 'time))
    (define dt (- t1 t0))
    (if (< dt 1e-7) (set! dt 1e-7) ())
    (if (< n 1) (set! n 1) ())
    (list n dt (* 1e6 (/ dt n)) (/ n dt))
)

;; }}}
;; {{{ gcd

(define (gcd x y)
    (define (gcd$ x y)
        (if
            (equal? y 0)
            x
            (gcd$ y (% x y))
        )
    )
    (cond
        ((lt? x y) (gcd y x))
        ((equal? x 0) 1)
        (#t (gcd$ x y))
    )
)

;; }}}

;; EOF
