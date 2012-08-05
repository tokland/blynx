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
  get_types: -> this
  get_all_types: ->
    type = @get_types()
    _.flatten1(if type.constructor.name == "Array" then (t.get_all_types() for t in type) else [type])
  @inspect: -> constructor.name
  @toString: -> @inspect()
  join: (namespace) ->
    new_args = ((namespace[tv] or tv) for tv in @args)
    new @constructor(new_args)

class Variable extends TypeBase
  variable: true
  constructor: (@name) -> 
  toString: -> @name 
  join: (namespace) -> namespace[this] or this

## Basic
  
class Int extends TypeBase

class Float extends TypeBase

class String extends TypeBase

## Tuple 

class Tuple extends TypeBase
  toString: -> "(" + (type.toString() for type in @args).join(", ") + ")"
  get_types: -> @args

class NamedTuple extends TypeBase
  toString: -> "(" + (((if k then "#{k}: " else "") + t) for [k, t] in @args).join(", ") + ")"
  get_types: -> (v for [k, v] in @args)
  join: (namespace) ->
    new_args = ([k, t.join(namespace)] for [k, t] in @args)
    new @constructor(new_args)
  merge: (other) ->
    index_to_key = _.mash([i, k] for [k, v], i in @args)
    key_to_index = _.mash([k, i] for i, k of index_to_key)
    if (key = _.first(key for [key, type] in other.args when key not of key_to_index))
      error("ArgumentError", "argument '#{key}' not defined")
    indexed_pairs = _.map other.args, ([other_key, type], idx) ->
      key = other_key or index_to_key[idx]
      {position: parseInt(key_to_index[key]), pair: [key, type]}
    new NamedTuple(o.pair for o in _.sortBy(indexed_pairs, (o) -> o.position))

# Function

class Function extends TypeBase
  constructor: (@args, @result, @trait, @restrictions) ->
    super
  toString: ->
    _([
      "#{@args.toString()} -> #{@result.toString()}"
      ("where(#{("#{k}@#{v}" for [k, v] in @restrictions)})") if _(@restrictions).isNotEmpty()
      "[trait #{@trait}]" if @trait
    ]).compact().join(" ")
  toShortString: -> "#{@args.toString()} -> #{@result.toString()}"
  get_types: -> 
    [@args, @result]
  join: (namespace) ->
    new_restrictions = ([tv.join(namespace), type] for [tv, type] in @restrictions)
    new Function(@args.join(namespace), @result.join(namespace), @trait, new_restrictions)

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

exports.match_types = match_types = (expected, given) ->
  #console.log("match_types", expected, given)
  if expected.variable and not given.variable
    _.mash([[expected, given]])
  else if expected.classname == given.classname
    expected_types = expected.get_types()
    given_types = given.get_types()
    if expected_types.constructor.name == "Array"
      if expected_types.length != given_types.length
        false
      else
        namespaces = (match_types(e, g) for [e, g] in _.zip(expected_types, given_types))
        if _.all(namespaces, _.identity)
          _.freduce namespaces, {}, (acc, namespace) -> _.merge(acc, namespace)
        else
          false
    else
      {}
  else
    false

##

lib.exportClasses(exports,
  [Int, Float, String, Tuple, NamedTuple, Function, Variable])
