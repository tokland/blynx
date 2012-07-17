#!/usr/bin/coffee
_ = require('./underscore_extensions')
lib = require './lib'
{debug, error} = lib

class TypeBase
  @inspect: -> constructor.name
  constructor: -> @classname = @constructor.name
  inspect: -> @toString()

class Scalar extends TypeBase
  scalar: true
  toString: -> @classname

class Composed extends TypeBase
  scalar: false

## Scalar
  
class Int extends Scalar

class Float extends Scalar

class String extends Scalar

## Composed 

class Tuple extends Composed
  constructor: (@types) -> super()
  toString: -> "(" + _(@types).invoke("toString").join(", ") + ")"

class Function extends Composed
  constructor: (@fargs, @result) -> super()
  toString: -> "#{@fargs.toString()} -> #{@result.toString()}"

##

lib.exportClasses(exports, [Int, Float, String, Tuple, Function])
