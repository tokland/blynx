should = require 'should'
assert = require 'assert'
grammar = require 'grammar'
compiler = require 'compiler'
_ = require 'underscore_extensions'

should_throw = (error_string) -> 
  {_should_throw: true, error_string}
  
should_have_bindings = (bindings) -> 
  {_should_have_bindings: true, bindings}

should_have = (what) -> 
  _(what).merge(_should_have: true)
  
tests = [
  ["", undefined]
  
  # Pre-defined types

  ["x = 1", should_have(bindings: {x: "Int"})]
  ["x = 1.23", should_have(bindings: {x: "Float"})]
  ['x = "hello"', should_have(bindings: {x: "String"})]
  ['x = (1, 1.23, "hello")', should_have(bindings: {x: "(Int, Float, String)"})]

  # ADT

  ["""
    type Bool = True | False
    x = True
    y = False
  """, should_have(bindings: {x: "Bool", y: "Bool"})]

  ["""
    type Bool = True | False
    type Bool = AnotherTrue | AnotherFalse
  """, should_throw("TypeError: type 'Bool' already defined")]

  ["""
    type Bool = True | False
    type AnotherBool = AnotherTrue | False
  """, should_throw("BindingError: symbol 'False' already bound to type 'Bool'")]

  # ADT with arguments
  
  ["""
    type Entity = Square(side: Int) | Point
    square = Square(5)
    point = Point
  """, should_have(bindings: {square: "Entity", point: "Entity"})]

  ["""
    type Entity = Square(side: Int) | Point
    Square(1.23)
  """, should_throw("TypeError: function '(side: Int) -> Entity', called with arguments '(side: Float)'")]

  # ADT with type arguments
  
  ["""
    type Either(a, b) = Left(value: a) | Right(error: b)
    left = Left(1)
    right = Right(1.23)
  """, should_have(bindings: {left: "Either(Int, b)", right: "Either(a, Float)"})]

  ["""
    type List(a) = Nil | Cons(head: a, tail: List(a))
    xs = Cons(1, Cons(2, Nil))
    ys = Nil
  """, should_have(bindings: {xs: "List(Int)", ys: "List(a)"})]
  
  # Symbol bindings
  
  ["""
    x = 1
   """, should_have(bindings: {x: "Int"})]

  ["""
    x =
      1
      y = 2.3
      y
   """, should_have(bindings: {x: "Float"})]

  ["x", should_throw("NameError: undefined symbol 'x'")]

  ["""
    x =
      y = 1
      2
    y
   """, should_throw("NameError: undefined symbol 'y'")]
   
  # Function bindings

  ["""
    f0(): Int = 1
    x = f0()
   """, should_have(bindings: {f0: "() -> Int", x: "Int"})]
  
  ["""
    f0(): Int = 1
    f0()
   """, 1]

  ["""
    f1(x: Float): Int = 1
    x = f1(1.23)
   """, should_have(bindings: {f1: "(x: Float) -> Int", x: "Int"})]

  ["""
    f1(x: Float): Int = 1
    f1(1.23)
   """, 1]

  ["""
    f2(x: Int, y: Int): Int = 
      z = 3
      z
    f2(1, 2)
   """, 3]

  ["""
    f2(x: Int, y: Int): Int = 10
    f2(1)
   """, should_throw("ArgumentError: function 'f2' takes 2 arguments but 1 given")]

  ["""
    f(x: Int): Float = 1.23
    f("hello")
   """, should_throw("TypeError: function '(x: Int) -> Float', called with arguments '(x: String)'")]

  ["""
    f1(x: Int): Float = x
    f1(1)
   """, should_throw("TypeError: function 'f1' should return 'Float' but returns 'Int'")]

  ["""
    f1(x: Int, x: Int): Int = 1
   """, should_throw("BindingError: argument 'x' already defined in function binding")]
  
  # Function calls

  ["""
    f(x: Int, y: Int): Int = x
    f(1, 2)
   """, 1]

  ["""
    f(x: Int, y: Int): Int = x
    f(1, y=2)
   """, 1]

  ["""
    f(x: Int, y: Int): Int = x
    f(x=1, 2)
   """, 1]

  ["""
    f(x: Int, y: Int): Int = x
    f(x=1, y=2)
   """, 1]

  ["""
    f(x: Int, y: Int): Int = x
    f(y=2, x=1)
   """, 1]

  ["""
    f(x: Int, y: Int, z: Int): Int = z
    f(1, z=3, y=2)
   """, 3]

  # Chain calls
  
  ["""
    f(x: Int): Float = 1.23
    g(): (Int) -> Float = f
    x = g()(1)
   """, should_have(bindings: {x: "Float"})]

  ["""
    f(x: Int): Float = 1.23
    x = (f)(1)
   """, should_have(bindings: {x: "Float"})]

  ["""
    x = 1
    x()
   """, should_throw("TypeError: binding 'Int' called, but it's not a function")]

  ["""
    f(x: Int, y: Int): Int = x
    f(x=1, x=1)
   """, should_throw("ArgumentError: function call repeats argument 'x'")]

  ["""
    f(x: Int, y: Int): Int = x
    f(x=1, z=1)
   """, should_throw("ArgumentError: argument 'z' not defined")]
  
  # Paren expression

  ["""
    (~~)(x: Int, y: Int): Int = x
    (%%)(x: Int, y: Int): Int = y
    (1 ~~ 2) %% 3 
   """, 3]
  
  # Type signatures
  
  ["""
    f(x: Int): Int = x
    f(1)
  """, 1]

  ["""
    f(x: Float): Float = x
    f(1.23)
  """, 1.23]

  ["""
    f(x: String): String = x
    f("hello")
  """, "hello"]

  ["""
    f(x: (Int, Float)): (Int, Float) = x 
    f((1, 2.34))
  """, [1, 2.34]]

  ["""
    type Either(a, b) = Left(value: a) | Right(error: b)

    f(x: Int): Either(Int, b) = 
      Left(4)
      
    res = f(1)
  """, should_have(bindings: {res: "Either(Int, b)"})]

  ["""
    f1(x: Int): Float = 1.2
    g1(f: (Int) -> Float): Float = f(5)
    x = g1(f1)
  """, should_have_bindings
        f1: "(x: Int) -> Float",
        g1: "(f: (Int) -> Float) -> Float", 
        x: "Float"
  ]

  ["""
    f(x: Int): Int = x
    g(x: Int, f2: (arg_x: Int) -> Int): Int = f2(arg_x=x)
    x = g(1, f)
  """, should_have_bindings
        f: "(x: Int) -> Int",
        g: "(x: Int, f2: (arg_x: Int) -> Int) -> Int", 
        x: "Int"
  ]

  # Infix operators
  
  ["""
    (+)(x: Int, y: Int): Int = 1
    (-)(x: Int, y: Int): Int = 2
    (^)(x: Int, y: Int): Int = 3
    (~)(x: Int, y: Int): Int = 4
    (<)(x: Int, y: Int): Int = 5
    (>)(x: Int, y: Int): Int = 6
    (!)(x: Int, y: Int): Int = 7
    (*)(x: Int, y: Int): Int = 8
    (/)(x: Int, y: Int): Int = 9
    (%)(x: Int, y: Int): Int = 10
    (&)(x: Int, y: Int): Int = 11
    (|)(x: Int, y: Int): Int = 12
    
    (0+0, 0-0, 0^0, 0~0, 0<0, 0>0, 0!0, 0*0, 0/0, 0%0, 0&0, 0|0)
   """, [1..12]]

  ["""
    (++)(x: Int, y: Int): Int = 1
    (--)(x: Int, y: Int): Int = 2
    (==)(x: Int, y: Int): Int = 3
    (!=)(x: Int, y: Int): Int = 4
    (<=)(x: Int, y: Int): Int = 5    
    (>=)(x: Int, y: Int): Int = 6
    (^^)(x: Int, y: Int): Int = 7
    (~~)(x: Int, y: Int): Int = 8
    (!!)(x: Int, y: Int): Int = 9
    (::)(x: Int, y: Int): Int = 10
    (&&)(x: Int, y: Int): Int = 11
    (||)(x: Int, y: Int): Int = 12
    
    (0++0, 0--0, 0==0, 0!=0, 0<=0, 0>=0, 0^^0, 0~~0, 0!!0, 0::0, 0&&0, 0||0)
   """, [1..12]]

  ["""
    ($-)(x: Int): Int = 1
    ($+)(x: Int): Int = 2
    ($!)(x: Int): Int = 3
    ($~)(x: Int): Int = 4
    
    (-0, +0, !0, ~0)
   """, [1, 2, 3, 4]]
   
   ["""
      f(x: Int, y: Int): Int = y
      (~~) = f
      1 ~~ 2
    """, 2]

   ["""
      (!!)(x: Int, y: Int): Int = y
      (~~) = (!!)
      1 ~~ 2
    """, 2]
    
  # Comments

  ["""
    # this is a comment
    x = 1
    # another comment
    y = 2
    # yet another comment
  """, should_have(bindings: {x: "Int", y: "Int"})]

  # Traits
  
  ["""
    traitinterface Showable a
      str: (x: a) -> String
      
    type Semaphore traits(Showable) = Red | Yellow | Green

    trait Showable Semaphore
      str(x: Semaphore): String = "SomeValueUntilWeCanMatch"

    x = str(Red)
  """, should_have(bindings: {x: "String"})]
]

describe "compiler", ->
  for test in tests
    [source, expected] = test
    do (source, expected) ->
      if typeof expected == "object" 
        if expected._should_throw
          msg = expected.error_string
          it "should throw exception:\n\n#{source}", ->
            (-> compiler.compile(source, skip_prelude: true)).
              should.throw(msg, "Failed on #{source}")
        else if expected._should_have
          bindings = expected.bindings
          for name, expected_type_string of bindings
            do(name, expected_type_string) -> 
              it "'#{name}' should have type '#{expected_type_string}'", ->
                {env} = compiler.compile(source, skip_prelude: true)
                type_string = env.get_binding(name).inspect()
                assert.deepEqual(type_string, expected_type_string, "Failed on:\n#{source}")
      else
        it "should compile:\n\n#{source}", ->
          output = compiler.run(source, skip_prelude: true)
          assert.deepEqual(output, expected, "Failed on #{source}")
