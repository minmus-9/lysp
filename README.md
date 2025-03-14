# Python LYSP: Solution In Search Of A Problem

OH NO! Another &^%ing LISP written in Python??! Yeah, and its name even
has a %^#%$ `P` and a &^@&^ `Y` in it.

This one is a little different from the others I've studied in that it

- was written for the explicit purpose of getting through ``Structure
and Interpretation of Computer Programs'' (SICP aka the Wizard Book,
see the references below), and

- has been written in continuation-passing-style (CPS) and uses
trampolines throughout (see refs).

It supports first-class continuations of unlimited extent via
`call/cc` and also has proper tail-call support for unlimited tail
recursion:

```
(define (loop f)
    (define c (call/cc (lambda (cc) cc)))
    (f)
    (c c))

(define (while f)
    (if (f) (while f) ()))

(define (! n)
    (define (iter product k)
        (if (< k 2)  product  (iter (* product k) (- k 1))))
    (iter 1 n))

(print (! 100000))  ;; Python printing takes as long as the lysp calculation!
```

It's fairly complete in that I was able to work through SICP with this
interpreter; in fact, this is an implementation of some of the material
in chapter 5 in Python instead of Scheme. I wrote several LISPs while
reading SICP but this is the best of them (it is very slow of course).

You won't blow out the Python runtime stack with this LISP because
it isn't recursive at the Python level -- due to the use of trampolines
and CPS. The VM uses registers and an explicit stack to maintain state
between CPS jumps; purely recursive code also makes heavy use of this
stack:

```
(define (! n) (if (< n 2)  1  (* n (! (- n 1)))))
```

Consider this repository as a digital pensieve of how trampolines
and CPS work. Hopefully it'll be of interest and help others get CPS.
Aside from that, as a practical library, this code is a SISOAP.

If you think of something useful to do with it, please let me know!

## Running the Code

Use
```
./lisp.py -
```
to run the REPL and
```
./lisp.py examples/factorial.lisp
```
to run code from a file. Finally,
```
./lisp.py file1 file2 ... fileN -
```
loads the specified files and then enters the REPL.

Note that `lisp.lisp` is automatically loaded by `lisp.py`.

## The Language

The core language is pretty much complete I think:

|Special Form|Description|
|--------------------------|-----------------------------|
|`(begin e1 e2 ...)`|evaluate the expressions in order and return the value of the last one|
|`(cond ((p c) ...)`|return `(eval c)` for the `(eval p)` that returns true|
|`(define sym value)`|bind `value` to `sym` in the current environment|
|`(define (sym args) body)`|bind `(lambda (args) body)` to `sym` in the current environment|
|`(if p c a)`|if `Predicate` then `Consequent` else `Alternative`|
|`(lambda (args) body)`|create a function|
|`(quasiquote x)`|aka \`, begin quasiquoted form|
|`(quote obj)`|aka `'`, returns obj unevaluated|
|`(set! sym value)`|redefine the innermost definition of `sym`|
|`(special sym proc)`|define a special form|
|`(special (sym args) body)`|define a special form as `(lambda (args) body)`|
|`(trap obj)`|returns a list containing a success-flag and a result or error message|
|`(unquote x)`|aka `,` unquote x|
|`(unquote-splicing x)`|aka `,@` unquote and splice in x|

Quasiquotation is supported; see lisp.lisp for some examples. There is no
macro system in this LISP, just quasiquote.

|Primitive|Description (see the source)|
|--------------------------|------------------------------|
|`()`|the empty list aka false|
|`#t`|true singleton|
|`(apply proc args)`|call `proc` with `args`|
|`(atom? obj)`|return true if obj is an atom: `()` `#t` or symbol|
|`(call/cc (lambda (cc) body))`|also `call-with-current-continuation`|
|`(call/cc)`|fast sugar for `(call/cc (lambda (cc) cc))`|
|`(car list)`|head of list|
|`(cdr list)`|tail of list|
|`(cons obj1 obj2)`|create a pair or prepend `obj1` to list `obj2`|
|`(/ n1 n2)`|`n1 / n2`|
|`(eq? x y)`|return true if 2 atoms are the same|
|`(equal? n1 n2)`|return true if n1 and n2 are equal|
|`(error obj)`|raise `lcore.error` with `obj`|
|`(eval obj)`|evaluate `obj`|
|`(eval obj n_up)`|evaluate `obj` up `n_up` namespaces|
|`(exit obj)`|raise `SystemExit` with the given `obj`|
|`(< n1 n2)`|return #t if `n1` < `n2` else ()|
|`(* n1 n2)`|return `n1 * n2`|
|`(nand n1 n2)`|return `~(n1 & n2)`|
|`(null? x)`|return #t if x is () else ()|
|`(print ...)`|print a list of objects space-separated followed by a newline|
|`(range start stop step)`|same as the python function, *much* faster than FFI|
|`(set-car! pair value)`|set the car of a pair|
|`(set-cdr! pair value)`|set the cdr of a pair|
|`(- n1 n2)`|`n1 - n2`|
|`(type obj)`|return a symbol representing the type of `obj`|

You'll note that `+` is not in the list. It is implemented in the standard
library in terms of subtraction. `nand` is used to create all of the other
basic bitwise ops. There's no predefined I/O either since it isn't clear
what is wanted there, but see the next section.

## FFI

Rather than adding everything under the sun as a built-in (I'm thinking of
the large number of functions in the `math` module, specifically), I chose
to create a Foreign Function Interface (FFI) to Python to ease incorporating
additional things into this LISP-ish doodad. With this interface, Python gets
to work with native Python lists instead of LISP lists; values are converted
back and forth automatically.

The net result is that the `math` module interface looks like
```
(math symbol args...)
```
so `sin(x)` can be obtained with
```
(math 'sin x)
```
where `(math)` is something close to (sans error checking):
```
@ffi("math")
def op_ffi_math(args):
    import math
    sym = args.pop(0)
    return getattr(math, str(sym))(*args)
```
which gets you the whole `math` module at once. See the "ffi" section of
`lisp.py` for the whole scoop. There are interfaces to `math`, `random`,
and `time` so far, along with some odds and ends like `(shuffle)` that
require separate treatment.

## The Files

The evaluator lives in 2 files: `lcore.py` and `lisp.py`. The runtime
engine lives in `lcore.py` and is where the real action happens in
terms of trampolines, CPS, etc. The file `lisp.py` implements all of
the special forms, primitives, LISP-Python Foreign Function
Interface (FFI), etc. on top of `lcore.py`. A useful LISP runtime is
in the file `lisp.lisp` and defines things like `let/let*/letrec` and
whatnot.

Please pardon my goofy Pythonic LISP coding style. I'm new to LISP and
haven't quite hit the groove yet.

## Code Overview

Aside from the CPS thing, the code in `lisp.py` is fairly
straightforward: each operator receives an `lcore.Context` instance
that contains the interpreter's execution state (registers, stack,
symbol table, and global environment) and returns a continuation. In
the python realm, a continuation is just a python function that is
called from `Context.trampoline()`. The trampoline is really a means
of implementing `goto` for languages that don't have `goto`. Like
Python or C. CPS is goto-driven programming.

The code in `lcore.py` is fairly optimized and is filled with
unidiomatic and somewhat bizarre constructs including gems like
```
try:
    _ = proc.__call__
    [do something with callable proc]
except AttributeError:
    pass
```
instead of
```
if callable(proc):
    [do something with callable proc]
```
and
```
if x.__class__ is list:
    [do something]
```
instead of
```
if isinstance(x, list):
    [do something]
```

What's happening here is the elimination of Python function/method
calls *at all costs*; in particular, at the cost of readability :D
Function calls are so expensive that eliminating them can give you
a 100% speedup (Python 3.10.12 Pop-OS! 22.04 LTS on a System76
i7-based Meerkat).

Pairs are represented as 2-lists so `cons(x, y)` is `[x, y]`. This,
or its equivalent, is about the only thing that works with the
mutators `set-car!` and `set-cdr!`. In particular, using regular
Python lists as LISP lists breaks when you get to `set-cdr!`.

The runtime stack is also implemented as a LISP linked list of pairs.
This is almost twice as fast as using the `list.append()` and
`lisp.pop()` methods (pronounced *function calls*). You get the
idea. This choice makes continuations *cheap*. If you use a regular
list for the stack, you have to slice the whole thing to create or
call a continuation.

The `Context` class provides `.push()` and `.pop()` methods but
`lcore.py` doesn't use them internally. The `leval()` family of
functions inlines all of the stack operations for speed; this code
needs all the help it can get, speed-wise. You'll see things like
```
ctx.s = [x, ctx.s]  ## push(x)
```
and
```
ret, ctx.s = ctx.s
return ret  ## pop()
```
all over the place in `lcore.py`.

Much of the code in `lisp.py` is more traditional and idiomatic. It
uses `.push()`, `.pop()`, `car()`, `cdr()`, and so on to enhance
clarity and let you focus on *what* is going on instead of *how*
it's happening. The `unary()` and `binary()` helper functions are
optimized a bit because they're used so much. Certain other "hot
spots" have been optimized based on profiling data.

Passing circular data structures into the core will definitely cause
infinite loops. Fixing this would have a grave performance impact
and so it hasn't been done.

The Python GC is the LISP GC and so any LISP circular references
should eventually get cleaned up.

Internal exceptions (wrong #args etc) generate Python exceptions
that are handled in the usual Python way; LISP exception handling
is very basic (see `trap`) and terrible (see `trap`).

## License

This code is licensed under the GPLv3:

```
lysp - python lisp: solution in search of a problem
       https://github.com/minmus-9/lysp
Copyright (C) 2025  Mark Hays (github:minmus-9)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

The file LICENSE contains a copy of the full GPL text.

## References

Here are some lisp-related refs that *heavily* influenced this code:

- https://web.mit.edu/6.001/6.037/sicp.pdf
- https://buildyourownlisp.com
- https://www.hashcollision.org/hkn/python/pyscheme/
- https://norvig.com/lispy.html
- https://norvig.com/lispy2.html
- https://github.com/rain-1/single_cream
- https://github.com/Robert-van-Engelen/tinylisp
- https://dl.acm.org/doi/pdf/10.1145/317636.317779
- https://en.wikipedia.org/wiki/Continuation-passing_style
- https://blog.veitheller.de/Lets_Build_a_Quasiquoter.html
- https://paulgraham.com/rootsoflisp.html
- https://www-formal.stanford.edu/jmc/index.html
- https://www-formal.stanford.edu/jmc/recursive.pdf
- https://legacy.cs.indiana.edu/~dyb/papers/3imp.pdf
