should = require 'should'
assert = require 'assert'
grammar = require 'grammar'
compiler = require 'compiler'

should_throw = (name) -> {_should_throw: name}
  
tests = [
  ["", undefined]

  # Pre-defined types

  ["1", 1]
  
  ["1.23", 1.23]
  
  ['"hello there"', "hello there"]
  ['"hello \\"inner\\" there"', 'hello "inner" there']
  
  ["()", []]
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
   """, should_throw("ArgumentsError: function 'f2' takes 2 arguments but 1 given")]

  ["""
    f(x: Int): Float = 1.23
    f("hello")
   """, should_throw("TypeError: function '(Int) -> Float', called with arguments '(String)'")]
   
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
]

describe "compiler", ->
  for test in tests
    [source, expected] = test
    do (source, expected) ->
      if typeof expected == "object" and (msg = expected._should_throw)
        it "should throw exception:\n\n#{source}", ->
          (-> compiler.compile(source, skip_prelude: true)).
            should.throw(msg, "Failed on #{source}")
      else
        it "should compile:\n\n#{source}", ->
          output = compiler.run(source, skip_prelude: true)
          assert.deepEqual(output, expected, "Failed on #{source}")
