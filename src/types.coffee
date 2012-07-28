#!/usr/bin/coffee
_ = require('./underscore_extensions')
lib = require './lib'
{debug, error} = lib

class TypeBase
  @inspect: -> constructor.name
  @toString: -> @inspect()
  constructor: (args) ->
    @args = args
    @classname = @constructor.name
  inspect: -> @toString()
  getTypes: -> [this] # this -> scalar

class Scalar extends TypeBase
  scalar: true
  toString: -> @classname

class Composed extends TypeBase
  scalar: false

# Variable
  
class Variable
  variable: true
  constructor: (@name) -> @classname = @constructor.name 
  toString: -> @name 
  @inspect: -> constructor.name
  @toString: -> @inspect()
  inspect: -> @toString()
  getTypes: -> [this]

## Scalar
  
class Int extends Scalar

class Float extends Scalar

class String extends Scalar

## Composed 

class Tuple extends Composed
  constructor: (@types) -> super()
  toString: -> "(" + _(@types).invoke("toString").join(", ") + ")"
  getTypes: -> @types

class NamedTuple extends Tuple
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

exports.buildType = buildType = (name, arity) ->
  class UserType extends Scalar
    constructor: (args) ->
      if args.length != @arity
        msg = "type '#{@.inspect()}' has arity #{@arity}, but #{args.length} arguments given"
        error("InternalError", msg)
      super
    name: name
    arity: arity
    toString: -> lib.optionalParens(name, @args)
    args: @args

##

exports.join_types = (base_type, namespace_pairs) ->
  namespace = _.mash([tv.name, type] for [tv, type] in namespace_pairs)
  new_args = ((namespace[tv.name] or tv) for tv in base_type.args)
  new base_type.constructor(new_args)

exports.match_types = match_types = (expected, given) ->
  if expected.variable and not given.variable
    [[expected, given]]
  else if expected.classname == given.classname
    if given.scalar
      []
    else
      pairs = _.zip(expected.getTypes(), given.getTypes())
      namespace = (match_types(e, g) for [e, g] in pairs)
      if _.all(namespace, _.identity) then _.flatten1(namespace) else false 
  else
    false

##

lib.exportClasses(exports, 
  [Int, Float, String, Tuple, NamedTuple, Function, Variable])
