#!/usr/bin/coffee
_ = require('underscore_extensions')
lib = require 'lib'
{debug, error} = lib

class TypeBase
  constructor: (args) ->
    @args = args or []
    @arity = @args.length
    @name = @constructor.name
  toString: -> @name
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
  @n: 0
  variable: true
  constructor: (name, @traits = []) ->
    @name = name or "a#{Variable.n++}" 
  toString: -> @name
  join: (namespace) -> namespace[this] or this

## Basic
  
class Int extends TypeBase

class Float extends TypeBase

class String extends TypeBase

class JSString extends TypeBase
class JSNumber extends TypeBase
class JSBool extends TypeBase
class JSObject extends TypeBase
class JSArray extends TypeBase

class Array extends TypeBase
  arity: 1
  toString: -> "A[#{@args[0].toString()}]"
  get_types: -> @args

## Tuple 

class Tuple extends TypeBase
  toString: -> "(" + (type.toString() for type in @args).join(", ") + ")"
  get_types: -> @args

class NamedTuple extends TypeBase
  toString: -> "(" + (((if k then "#{k}: " else "") + t) for [k, t] in @args).join(", ") + ")"
  get_keys: -> (k for [k, v] in @args)
  get_types: -> (v for [k, v] in @args)
  get_type: (key) -> _.first(v for [k, v] in @args when k == key)
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
  constructor: (@args, @result, @trait = null, @restrictions = []) ->
    super(@args)
  toString: ->
    _([
      "#{@args.toString()} -> #{@result.toString()}"
      ("where(#{("#{k}@#{v}" for [k, v] in @restrictions)})") if _(@restrictions).isNotEmpty()
      "[#{@trait}]" if @trait
    ]).compact().join(" ")
  toShortString: -> "#{@args.toString()} -> #{@result.toString()}"
  get_types: -> 
    [@args, @result]
  join: (namespace) ->
    new Function(@args.join(namespace), @result.join(namespace), @trait)

## ADT

exports.buildType = buildType = (name, arity) ->
  class UserType extends TypeBase
    constructor: (args) ->
      if args.length != @arity
        msg = "type '#{this.inspect()}' has arity #{@arity} but #{args.length} arguments given"
        error("InternalError", msg)
      super
      @name = name
    name: name
    arity: arity
    get_types: -> @args
    toString: -> 
      if name == "List" then "[#{@args[0].toString()}]" else lib.optionalParens(name, @args)

## Auxiliar functions

exports.match_types = match_types = (env, expected, given) ->
  if expected.variable and not given.variable
    if (trait = _.first(tr for tr in expected.traits when not env.is_type_of_trait(given, tr)))
      error("TypeError", "type '#{given}' does not implement trait '#{trait}'")
    _.mash([[expected, given]])
  else if expected.variable and given.variable
    {}
  else if !expected.variable and given.variable
    _.mash([[given, expected]])
  else if expected.name == given.name
    expected_types = expected.get_types()
    given_types = given.get_types()
    if expected_types.constructor.name == "Array"
      if expected_types.length != given_types.length
        false
      else
        namespaces = (match_types(env, e, g) for [e, g] in _.zip(expected_types, given_types))
        if _.all(namespaces, _.identity)
          acc = {}
          for namespace in namespaces
            for k, v of namespace
              if acc[k] and not match_types(env, acc[k], v)
                return false
            _(acc).update(namespace)
          acc 
        else
          false
    else
      {}
  else
    false

##

lib.exportClasses(exports, [
  JSString, JSNumber, JSBool, JSObject, JSArray
  Int, Float, String, Array, Tuple, NamedTuple, Function, Variable
])

