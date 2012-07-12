#!/usr/bin/coffee
_ = require('./underscore_extensions')
lib = require './lib'
{debug, error} = lib

class Variable
  @id: 1
  variable: true
  classname: "Variable"
  constructor: (options = {}) ->
    @wobbly = options.wobbly
    @id = Variable.id++ 
  toString: -> "a#{@id}" + (if @wobbly then "" else "r")
  subst: (namespace) -> namespace[@id] or this 
  matchType: (other) -> matchTypes(this, other)

class TypeBase
  @args: []
  variable: false
  constructor: -> @classname = @constructor.name
  inspect: -> @toString()
  subst: (namespace) -> this  
  matchType: (other) -> matchTypes(this, other)

##

class Scalar extends TypeBase
  scalar: true
  toString: -> @classname
  getTypes: -> [this]
  
class Int extends Scalar

class Float extends Scalar

class String extends Scalar

##

class Composed extends TypeBase

class Tuple extends Composed
  constructor: (@types) -> super()
  toString: -> "(" + _(@types).invoke("toString").join(", ") + ")"
  subst: (namespace) -> new Tuple(_(@types).invoke("subst", namespace)) 
  getTypes: -> @types

class Unit
  constructor: -> new Tuple([])
  
class Array extends Composed
  constructor: (type = undefined) ->
    super()
    @type = type or (new Variable(wobbly: true))
  subst: (namespace) -> new Array(@type.subst(namespace)) 
  toString: -> "[" + @type.toString() + "]"
  getTypes: -> [@type]

class Function extends Composed
  constructor: (@fargs, @result) -> super()
  toString: -> "#{@fargs.toString()} -> #{@result.toString()}"
  subst: (namespace) -> new Function(@fargs.subst(namespace), @result.subst(namespace))
  getTypes: -> [@fargs, @result]
    
class Record extends Composed
  constructor: (@namespace) -> super()
  toString: -> 
    "{" + ("#{k}: #{v.toString()}" for k, v of @namespace).join(", ") + "}"
  get: (id) -> @namespace[id]
  subst: (namespace) -> new Record([k, v.subst(namespace)] for k, v of @types)
  getTypes: -> @namespace

exports.createUserType = (classname, args) ->
  class UserType extends Composed
    @args: args
    constructor: (arg_types = {}) ->
      super()
      @arg_types = _.mash([a, arg_types[a] or new Variable(wobbly: true)] for a in args)
    toString: ->
      mapped = _(UserType.args).map(((arg) -> @arg_types[arg] or arg), this)
      lib.optionalParens(@classname, mapped)
    getTypes: -> @arg_types
    applyTypes: (types) -> new UserType(_(@arg_types).merge(types))

##

class TypeConstructor
  name: "TypeConstructor"
  constructor: (@type, @name, @args) ->
    klass = @type.constructor
    if (arg = _(@args).detect((arg) -> not _(klass.args).include(arg))) 
      error("TypeError", "Unknown type variable #{arg} in type constructor #{@name}") 
  toString: ->
    if _(@args).isEmpty() then @type else "(#{@args.join(', ')}) -> #{@type}"
  buildType: (args) ->
    if args.length != @args.length
      error("ArgumentsError", "#{@name} takes #{@args.length} arguments, #{args.length} given")
    arg_types = _.mash(_.zip(@args, args))
    expected_types = (arg_types[arg] for arg in @args)
    if _(expected_types).isNotEqual(args)
      error("TypeError", "Type Constructor #{@name} expected types " + 
        "(#{expected_types.join(', ')}), but (#{args.join(', ')}) given")
    @type.applyTypes(arg_types)

matchTypes = (a, b, vars = {}) ->
  match = if a.variable and b.variable
    if vars[a.id] && not vars[a.id].id == b.id
      false
    else 
      vars[a.id] = b
      true
  else if a.variable and !b.variable
    if vars[a.id] && not matchTypes(vars[a.id], b)
      false
    else
      vars[a.id] = b
      true
  else if !a.variable and b.variable
    a.wobbly or b.wobbly 
  else if !a.variable and !b.variable
    if a.classname != b.classname
      false
    else if a.scalar
      true
    else
      [ats, bts] = [a.getTypes(), b.getTypes()]
      if _.isNotEqual(_.keys(ats), _.keys(bts))
        false
      else
        xs = (matchTypes(a2, b2, vars) for [a2, b2] in _.zip(_.values(ats), _.values(bts)))
        _.all(xs, _.identity)
          
  if match then vars else false

lib.exportClasses(exports, [TypeBase, Scalar, Composed, Int, Float, String, Array, 
  Function, Tuple, Record, TypeConstructor, Variable])
exports.matchTypes = matchTypes
