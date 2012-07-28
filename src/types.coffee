#!/usr/bin/coffee
_ = require('./underscore_extensions')
lib = require './lib'
{debug, error} = lib

class TypeBase
  constructor: (args) ->
    @args = args
    @classname = @constructor.name
  toString: -> @classname
  inspect: -> @toString()
  getTypes: -> this
  @inspect: -> constructor.name
  @toString: -> @inspect()

class Variable
  variable: true
  constructor: (@name) -> 
  toString: -> @name 
  inspect: -> @toString()
  getTypes: -> this

## Basic
  
class Int extends TypeBase

class Float extends TypeBase

class String extends TypeBase

## Tuple 

class Tuple extends TypeBase
  toString: -> "(" + (t.toString() for t in @args).join(", ") + ")"
  getTypes: -> @args

class NamedTuple extends TypeBase
  toString: -> "(" + (((if k then "#{k}: " else "") + t) for [k, t] in @args).join(", ") + ")"
  getTypes: -> (v for [k, v] in @args)

# Function

class Function extends TypeBase
  constructor: (@args, @result) -> super
  toString: -> "#{@args.toString()} -> #{@result.toString()}"

## ADT

exports.buildType = buildType = (name, arity) ->
  class UserType extends TypeBase
    constructor: (args) ->
      if args.length != @arity
        msg = "type '#{this.inspect()}' has arity #{@arity} but #{args.length} arguments given"
        error("InternalError", msg)
      super
    name: name
    arity: arity
    toString: -> lib.optionalParens(name, @args)

## Auxiliar functions

exports.mergeNamedTuples = (base, given) ->
  index_to_key = _.mash([i, k] for [k, v], i in base.args)
  key_to_index = _.mash([k, i] for i, k of index_to_key)
  if (key = _.first(key for [key, type] in given.args when key not of key_to_index))
    error("ArgumentError", "argument '#{key}' not defined")
  indexed_pairs = _.map given.args, ([given_key, type], idx) ->
    key = given_key or index_to_key[idx]
    {position: parseInt(key_to_index[key]), pair: [key, type]}
  new NamedTuple(o.pair for o in _.sortBy(indexed_pairs, (o) -> o.position))

exports.join_types = (base_type, namespace_pairs) ->
  namespace = _.mash([tv.name, type] for [tv, type] in namespace_pairs)
  new_args = ((namespace[tv.name] or tv) for tv in base_type.args)
  new base_type.constructor(new_args)

exports.match_types = match_types = (expected, given) ->
  if expected.variable and not given.variable
    [[expected, given]]
  else if expected.classname == given.classname
    expected_types = expected.getTypes()
    given_types = given.getTypes()
    if expected_types.constructor.name == "Array"
      namespace = (match_types(e, g) for [e, g] in _.zip(expected_types, given_types))
      if _.all(namespace, _.identity) then _.flatten1(namespace) else false
    else
      []
  else
    false

##

lib.exportClasses(exports, 
  [Int, Float, String, Tuple, NamedTuple, Function, Variable])
