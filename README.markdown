Blynx is a functional statically-typed language that transcompiles to Javascript. 

State: _in development_ (alpha ~ Jan/2013)

# Features

  * Functional (impure, side-effects are allowed yet controlled).
  * Statically typed.
  * Common types built-in (boolean, integer, float, string, list, array, dictionary, tuple).
  * Algebraic data types.
  * Polymorphic types.
  * Type-traits (type-classes).
  * Automatic type-inference.
  * Pattern-matching.
  * Special syntax to write asynchronous code.
  * Access to external Javascript code. 

A more detailed overview: https://github.com/tokland/blynx/wiki/Overview

# Take a quick glance

### Project Euler #20 

_Find the sum of the digits in the number 100!_. We can write a compact one-liner:

```coffeescript
[1..100].reduce1((*)).str.chars.map(int).reduce1((+)) #=> 648 : Int
```

That's ok to solve this particular problem, but programming is about building abstractions, so let's split the code into re-usable functions:

```coffeescript
sum(xs: [a]): a where(a@Num) = xs.reduce(0: a, (+))
product(xs: [a]): a where(a@Num) = xs.reduce(1: a, (*))
factorial(n: Int): Int = [1..n].product
digits(n: Int): [Int] = n.str.chars.map(int)

sum(digits(100.factorial)) #=> 648 : Int
```

Notice that now, thanks to the abstractions and the syntax of the language, the final expression is able to mimic the exact formulation of the problem.

### Functional sort

```coffeescript
sort(xs: [a]): [a] where(a@Ord) = 
  match xs
    [] -> []
    [pivot|rest] ->
      (smaller, greater) = rest.partition(x -> x < pivot)
      smaller.sort ++ [pivot] ++ greater.sort

[4, 3, 2, 5, 1].sort #=> [1, 2, 3, 4, 5] : [Int]
```
