should = require 'should'
assert = require 'assert'
grammar = require 'grammar'
compiler = require 'compiler'

should_throw = (error_string) -> 
  {_should_throw: true, error_string: error_string}
  
should_have_binding = (name, type_string) -> 
  {_should_have_binding: true, type_string: type_string, name: name}
  
tests = [
  ["", undefined]

  # Pre-defined types

  ["1", 1]
  
  ["1.23", 1.23]
  
  ['"hello there"', "hello there"]
  ['"hello \\"inner\\" there"', 'hello "inner" there']
  
  ["(1, 2.5)", [1, 2.5]]
  ["(1, 2.5, 5)", [1, 2.5, 5]]
  
  # Symbol bindings
  
  ["""
    x = 1
    x
   """, 1]

  ["""
    x =
      1
      y = 2
      y
    x
   """, 2]

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
    f0()
   """, 1]

  ["""
    f1(x: Int): Int = x
    f1(1)
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
  """, should_have_binding("res", "Either(Int, b)")]
  
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
   
  # ADT

  ["""
    type Bool = True | False
    f(x: Bool, y: Bool): Int = 1
    f(True, False)
  """, 1]

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
    type Shape = Square(side: Int) | Circle
    f(x: Shape, y: Shape): Int = 1
    f(Square(5), Circle)
  """, 1]

  ["""
    type Shape = Square(side: Int) | Circle
    Square(1.23)
  """, should_throw("TypeError: function '(side: Int) -> Shape', called with arguments '(side: Float)'")]

  # ADT with type arguments
  
  ["""
    type Either(a, b) = Left(value: a) | Right(error: b)
    left = Left(1)
  """, should_have_binding("left", "Either(Int, b)")]
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
        else if expected._should_have_binding
          expected_type_string = expected.type_string
          name = expected.name
          it "should have type '#{expected_type_string}'", ->
            {env} = compiler.compile(source, skip_prelude: true)
            type_string = env.get_binding(name).inspect()
            assert.deepEqual(type_string, expected_type_string, "Failed on #{source}")
      else
        it "should compile:\n\n#{source}", ->
          output = compiler.run(source, skip_prelude: true)
          assert.deepEqual(output, expected, "Failed on #{source}")
