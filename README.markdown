Blynx is a statically-typed functional language that transcompiles to Javascript. 

State: _in development_ (alpha ~ Jan/2013)

# Features

  * Functional (but controlled side-effects are allowed).
  * Statically typed.
  * Common types built-in: boolean, integer, float, string, list, array, dictionary, tuple.
  * Algebraic data types.
  * Polymorphic types.
  * Type-traits (type-classes).
  * Automatic type-inference.
  * Pattern-matching.
  * Simple asynchronous code.
  * Easy integration with Javascript libraries. 

A more detailed overview: https://github.com/tokland/blynx/wiki/Overview

# Take a quick glance

### Project Euler #20 

_Find the sum of the digits in the number 100!_. A one-liner:

```coffeescript
[1..100].reduce(1, (*)).str.chars.map(int).reduce(0, (+)) #=> 648 : Int
```

That's ok to solve that particular problem, but programming is about building abstractions, so let's split it into re-usable functions:

```coffeescript
sum(xs: [a]): a where(a@Numeric) = xs.reduce(0, (+))
product(xs: [a]): a where(a@Numeric) = xs.reduce(1, (*))
factorial(n: Int): Int = [1..n].product
digits(n: Int): [Int] = n.str.chars.map(int)

sum(digits(100.factorial)) #=> 648 : Int
```

Notice that now, thanks to the abstractions and the language syntax, the final expression is able to mimic exactly the formulation of the problem.

### Functional sort

```coffeescript
sort(xs: [a]): [a] where(a@Orderable) = 
  match xs
    [] -> []
    (pivot::rest) ->
      (smaller, greater) = rest.partition(x -> x < pivot)
      smaller.sort ++ [pivot] ++ greater.sort

[4, 3, 2, 5, 1].sort #=> [1, 2, 3, 4, 5] : [Int]
```
