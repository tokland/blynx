should = require 'should'
grammar = require('grammar')
compiler = require 'compiler'

should_throw = (name) -> {_should_throw: name}
  
tests = [
  ["", undefined]

  # Pre-defined types

  ["1", 1]
  ["1.23", 1.23]
  ['"hello there"', "hello there"]
  
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
          should.equal(output, expected, "Failed on #{source}")

