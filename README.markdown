Blynx is a statically-typed functional language that transcompiles to Javascript. 

State: _in development_ (~ January 2013)

# Features

  * Functional (though impure -and controlled- side-effects are allowed).
  * Statically typed.
  * Basic types built-in: boolean, integer, float, string, list, array, dictionary, tuple.
  * Algebraic data types.
  * Polymorphic types.
  * Traits (also known as type-classes).
  * Automatic type-inference.
  * Pattern-matching.
  * Eager/strict evaluation.
  * Whitespace-relevant syntax.

# A quick glance

### Project Euler #20 

_Find the sum of the digits in the number 100!_. A one-liner:

```coffeescript
[1..100].reduce(1, (*)).str.chars.map(int).reduce(0, (+)) #=> 648 : Int
```

That's nice, but programming is building abstractions, let's split it into reusable functions:

```coffeescript
sum(xs: [a]): a where(a@Numeric) = xs.reduce(0, (+))
product(xs: [a]): a where(a@Numeric) = xs.reduce(1, (*))
factorial(n: Int): Int = [1..n].product
digits(n: Int): [Int] = n.str.chars.map(int)

sum(digits(100.factorial)) #=> 648 : Int
```

Note how the implementation mimics the formulation of the problem: "sum of the digits in the number 100!" becomes ```sum(digits(100.factorial))```.

### Functional sort

```coffeescript
sort(xs: [a]): [a] where(a@Orderable) = 
  match xs
    [] -> []
    (pivot::rest) ->
      (smaller, greater) = rest.partition(|x| -> x <= pivot)
      sort(smaller) ++ [pivot] ++ sort(greater)

[4, 3, 2, 5, 1].sort #=> [1, 2, 3, 4, 5] : [Int]
```

# More

  * Language overview: https://github.com/tokland/blynx/wiki/Overview
  * A complete example: https://github.com/tokland/blynx/blob/master/examples/validate-publications.coffeescript
