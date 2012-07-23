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

class NamedTuple extends Composed
  constructor: (@types) -> super()
  toString: -> "(" + ("#{k or '_'}: #{v}" for [k, v] in @types).join(", ") + ")"
  getTypes: -> (v for [k, v] in @types)

exports.mergeNamedTuples = (base, given) ->
  index_to_key = _.mash([i, k] for [k, v], i in base.types)
  key_to_index = _.mash([k, i] for i, k of index_to_key)
  if (key = _.first(key for [key, type] in given.types when key not of key_to_index))
    error("ArgumentError", "argument '#{key}' not defined")
  indexed_pairs = _.map given.types, ([given_key, type], idx) ->
    key = given_key or index_to_key[idx]
    {position: parseInt(key_to_index[key]), pair: [key, type]}
  new NamedTuple(o.pair for o in _.sortBy(indexed_pairs, (o) -> o.position))

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
   
lib.exportClasses(exports, [Int, Float, String, Tuple, NamedTuple, Function])
