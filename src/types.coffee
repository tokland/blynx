#!/usr/bin/coffee
_ = require('./underscore_extensions')
lib = require './lib'
{debug, error} = lib

class TypeBase
  @inspect: -> constructor.name
  @toString: -> @inspect()
  constructor: -> @classname = @constructor.name
  inspect: -> @toString()
  getTypes: -> [this]

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
  getTypes: -> @types

class Function extends Composed
  constructor: (@fargs, @result) -> super()
  toString: -> "#{@fargs.toString()} -> #{@result.toString()}"

## ADT

exports.buildType = (name) ->
  class UserType extends Scalar
    toString: -> name
  
##

exports.isSameType = isSameType = (expected, given) ->
  if expected.classname == given.classname
    if given.scalar
      true
    else
      pairs = _.zip(expected.getTypes(), given.getTypes())
      _.all(pairs, ([e, g]) -> isSameType(e, g))
  else
    false
   
lib.exportClasses(exports, [Int, Float, String, Tuple, Function])
