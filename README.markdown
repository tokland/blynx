Blynx is a statically-typed functional language that transcompiles to Javascript. 

State: _in development_ (~ January 2013)

# Features

  * Functional (but impure side effects are allowed).
  * Statically typed.
  * Basic types built-in: boolean, integer, float, string, list, array, dictionary, tuple.
  * Algebraic data types.
  * Polymorphic types.
  * Type-classes (traits).
  * Automatic type-inference.
  * Pattern-matching.
  * Eager/strict evaluation.
  * Whitespace-relevant syntax.

# A quick glance

Project Euler problem 20: Find the sum of the digits in the number 100!

```coffeescript
factorial(n: Int): Int = [1..n].product
euler20(): Int = factorial(100).str.chars.map(int).sum

euler20() #=> 648 : Int
```

Functional quicksort:

```quicksort
quicksort(xs: [a]): [a] = 
  match xs
    [] -> []
    (pivot::rest) ->
      smaller, greater = rest.partition(|x| -> x <= pivot)
      quicksort(smaller) ++ [pivot] ++ quicksort(greater)

quicksort([4, 3, 2, 5, 1]) #=> [1, 2, 3, 4, 5] : [Int]
```

# More

  * Language overview: https://github.com/tokland/blynx/wiki/Overview
  * Example: https://github.com/tokland/blynx/blob/master/examples/validate-publications.coffee
