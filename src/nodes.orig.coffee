#!/usr/bin/coffee
_ = require('./underscore_extensions')
types = require './types'
lib = require './lib'
{debug, error} = lib

native_infix_operators = "+ - * / % < <= == > >= || &&".split(" ")

translate_table = {
  "+": "plus", "-": "minus", "*": "mul", "/": "div",  "%": "per"
  "<": "lt",  ">": "gt", "==": "eq", "!": "neg", "?": "qm"
}
 
translateFunctionName = (s) ->
  (translate_table[c] or c for c in s).join("") 

class Root
  constructor: (@nodes) ->
  compile_with_process: (env) ->
    output = for node in @nodes when node
      {env, type} = node.process(env)
      node.compile(env) 
    {env, output: lib.indent(_(output).compact().join("\n"))}

# Statements

class Binding
  constructor: (@id_token, @block) ->
  process: (env) -> 
    type = @block.process(env).type
    {env: lib.addBinding(env, @id_token, type), type}
  compile: (env) -> 
    if lib.getClass(@block) == Expression
      "var #{@id_token} = #{@block.compile(env)};"
    else
      """
        var #{@id_token} = (function() {>>
          #{@block.compile(env, return: true)}<<
        }).call(this);
      """

class StatementExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "#{@value.compile(env)};"

class StatementIf
  constructor: (@condition, @block_true) ->
  process: (env) ->
    type = @condition.process(env).type
    if not (type instanceof env.types.Bool)
      error("TypeError", "IF condition must have type Bool but it's a #{type}")
    @block_true.process(env, parent_node: this)
  compile: (env) ->
    """
      if (#{@condition.compile(env)}) {>>
        #{@block_true.compile(env, return: false)}<<
      }
    """

class Function
  constructor: (@name, @args, @result_type, @block) ->
  process: (env) ->
    old_env = env
    arg_types = for arg in @args
      {env, type} = arg.process(env)
      [arg.name, type]
    {env, type: result_type} = @result_type.process(env)
    env.current_function = result_type #new types.Variable(wobbly: true)
    function_env = lib.addBindings(env, arg_types)
    {env: block_env, type: block_type} = @block.process(function_env)
    args_type = new types.Tuple(b for [a, b] in arg_types)
    if not block_type.matchType(result_type)
      error("TypeError", "function #{@name} has type #{args_type} -> " + 
        "#{result_type.toString()} but returns type #{block_type.toString()}")
    type = new types.Function(args_type, result_type)
    new_env = lib.addBinding(old_env, @name, type)
    {env: new_env, type: type}
  compile: (env) -> 
    js_args = _(@args).pluck("name").join(', ')
    fname = translateFunctionName(@name)
    if lib.getClass(@block) == Block
      """
        var #{fname} = function(#{js_args}) {>>
          #{@block.compile(env, return: true)}<<
        };
      """
    else
      "var #{fname} = function(#{js_args}) { return #{@block.compile(env)}; };"

class DefArg
  constructor: (@name, @type_node) ->
  process: (env) -> @type_node.process(env)
  compile: (env) -> @name

class NewType
  constructor: (@type_name_token, @type_args, @type_constructor_definitions) ->
  process: (env) -> 
    type = types.createUserType(@type_name_token, @type_args)
    env2 = lib.addType(env, @type_name_token, type)
    bindings = _(@type_constructor_definitions).invoke("binding", new type)
    {env: lib.addBindings(env2, bindings), type: type}
  compile: (env) ->
    constructors_comment = _(@type_constructor_definitions).invoke('inspect').join(' | ')
    type = lib.optionalParens(@type_name_token, @type_args)
    constructors = _(@type_constructor_definitions).invoke("compile", env)
    """
      // type #{type} = #{constructors_comment}
      #{constructors.join('\n')}
    """

class TypeConstructorDefinition
  constructor: (@id_cap_token, @args) ->
  inspect: ->
    lib.optionalParens(@id_cap_token, @args)
  compile: (env) ->
    args = ("#{arg}_#{idx}" for arg, idx in @args).join(", ")
    "var #{@id_cap_token} = api.tc(#{JSON.stringify(@id_cap_token)});"
  binding: (type_node) ->
    type = new types.TypeConstructor(type_node, @id_cap_token, @args)
    [@id_cap_token, type]
    
class TypeConstructor
  primitive_constructors: {"True": "true", "False": "false"}
  constructor: (@id_cap_token, @args) ->
  process: (env) ->
    type_constructor = env.bindings[@id_cap_token] or
      error("TypeError", "Type constructor not defined: #{@id_cap_token}")
    type = type_constructor.buildType(_(@args).invoke("type", env))
    {env, type: type}
  compile: (env) ->
    @primitive_constructors[@id_cap_token] or
      """new #{@id_cap_token}(#{_(@args).invoke("compile", env).join(', ')})"""

class External
  constructor: (@id_token, @id_as_name_token, @type) ->
    if @id_as_name_token[0]?.match(/^[A-Z]/)
      error("NameError", "Uppercase bindings are reserved for type " +
        "constructors: #{@id_as_name_token}. Use exports #{@id_as_name_token} as somename")
  process: (env) ->
    type = @type.type(env)
    new_env = lib.addBinding(env, @id_as_name_token, type) 
    {env: new_env, type}
  compile: (env) ->
    if @id_token != @id_as_name_token
      """
        // external #{@id_token} as #{@id_as_name_token}
        var #{@id_as_name_token} = #{@id_token};
      """ 
    else 
      "// external #{@id_token}"

class Return
  constructor: (@expression) ->
  process: (env, options = {}) ->
    if not env.current_function
      error("TypeError", "Cannot return outside a function")
    else if not options.parent_node or lib.getClass(options.parent_node) != StatementIf
      error("TypeError", "return can only be used in If statements")
    {env, type} = @expression.process(env)
    if not env.current_function.matchType(type) 
      error("TypeError", "Cannot match types in return: expecting type " +
        "#{env.current_function}, but found #{type}")
    new_env = _(env).merge(current_function: type)
    {env: new_env, type}
  compile: (env) -> "return #{@expression.compile(env)};"
    
# Expressions
 
class Block
  constructor: (@nodes) ->
  process: (env, options = {}) ->
    if _.isEmpty(@nodes)
      {env, type: new types.Unit}
    else 
      for node in @nodes
        {env, type} = node.process(env, options)
      {env, type}
  compile: (env, options = {}) ->
    compiled = _(@nodes).invoke("compile", env)
    [init, last] = [compiled[0...-1], _(compiled).last()]
    _.concat(init, if options.return then ["return #{last}"] else [last]).join("\n")

class FunctionCall
  constructor: (@name, @args) ->
  process: (env) ->
    function_type = @name.process(env).type
    if @args.length != function_type.fargs.types.length
      details = "takes #{function_type.fargs.types.length} but #{@args.length} given"
      error("ArgumentError", "#{@name.compile(env)} called with wrong number of arguments (#{details})")
    args = new types.Tuple(_(@args).invoke("type", env))
    namespace = function_type.fargs.matchType(args)
    if not namespace
      error("TypeError", "function #{@name.compile(env)} has type " + 
        "#{function_type} but called with #{args}")
    type = function_type.result.subst(namespace)
    {env, type}
  compile: (env) ->
    name = @name.compile(env)
    if name in native_infix_operators
      "(" + @args[0].compile(env) + " " + @name.compile(env) + " " + @args[1].compile(env) + ")"
    else 
      translateFunctionName(@name.compile(env)) + "(" + _(@args).invoke("compile", env).join(', ') + ")"

class ParenExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "(#{@value.compile(env)})"

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  type: (env) -> @process(env).type
  compile: (env) -> @value.compile(env)
  
class Identifier
  constructor: (@id_token) ->
  process: (env) ->
    if not env.bindings[@id_token]
      error("NameError", "undefined identifier '#{@id_token}'")
    {env, type: env.bindings[@id_token]}
  compile: (env) -> @id_token

class UnaryOp
  constructor: (@operation_token, @expression) ->
  type: (env) -> @process(env).type
  process: (env) ->
    # TODO: external (-) = (x: Int) -> Int 
    arithmentic_ops = ["-", "+"]
    boolean_ops = ["!"]
    type = @expression.process(env).type
    op = @operation_token
    msg = "#{op} #{@expression.compile(env)}:#{type}"
    if op in arithmentic_ops
      unless type instanceof env.types.Int or type instanceof env.types.Float
        error("TypeError", "Arithmentic UnaryOp #{op} not defined for #{msg}")
    else if op in boolean_ops
      unless type instanceof env.types.Bool
        error("TypeError", "Boolean UnaryOp #{op} not defined for #{msg}")
    else 
      error("TypeError", "UnaryOp #{@operation_token} not defined for #{msg}")
    {env, type}
  compile: (env) ->
    "#{@operation_token}#{@expression.compile(env)}"

class If
  constructor: (@condition, @block_true, @block_false) ->
  process: (env) ->
    type0 = @condition.process(env).type
    if not (type0 instanceof env.types.Bool)
      error("TypeError", "IF condition must have type Bool but it's a #{type0}")
    type1 = @block_true.process(env).type
    type2 = @block_false.process(env).type
    if not type1.matchType(type2)
      error("TypeError", "All IF-blocks must have the same type: #{type1} != #{type2}")    
    {env: env, type: type1} 
  compile: (env) ->
    if lib.getClass(@block_true) == Block 
      """
        (function() {>>
          if (#{@condition.compile(env)}) {>>
            #{@block_true.compile(env, return: true)}<<
          } else {>>
            #{@block_false.compile(env, return: true)}<<
          }<<
        }).call(this)
      """
    else
      "#{@condition.compile(env)} ? " + 
        "#{@block_true.compile(env)} : #{@block_false.compile(env)}"

# Implement ranges as nodes and not as functions so in the future
# we can iterate them lazily in loops.
class OpenRange
  constructor: (@start, @end) ->
  process: (env) ->
    if not (@start.process(env).type instanceof types.Int)
      error("TypeError", "Start index in range must be an Int")  
    else if not (@end.process(env).type instanceof types.Int)
      error("TypeError", "End index in range must be an Int")  
    {env, type: new env.types.Int}
  compile: (env) ->
    "api.openRange(#{@start.compile(env)}, #{@end.compile(env)})" 

class Range extends OpenRange
  compile: (env) ->
    "api.range(#{@start.compile(env)}, #{@end.compile(env)})" 

# Types

class Type
  constructor: (@id_token, @type_args) ->
  type: (env) -> @process(env).type
  process: (env) ->
    type = env.types[@id_token] or
      error("TypeError", "Unknown type: #{@id_token}")
    if type.args.length != @type_args.length
      error("Type Error", "Type #{@id_token} has #{type.args.length} arguments, " +
        "#{@type_args.length} given")
    types_namespace = for [arg_name, arg_type] in _.zip(type.args, @type_args)
      {env, type: arg_type} = arg_type.process(env)
      [arg_name, arg_type]
    {env, type: new type(_.mash(types_namespace))} 

class TypeVariable
  constructor: (@id_token) ->
  process: (env) ->
    type = env.typevars[@id_token]
    if type
      {env, type}
    else
      type = new types.Variable(wobbly: false)
      new_env = _.merge(env, _.mash([["typevars", _.clone(env["typevars"])]]))
      new_env.typevars[@id_token] = type
      {env: new_env, type: type}

class ArrType
  constructor: (@type_node) ->
  type: (env) -> @process(env).type
  process: (env) -> 
    {env: new_env, type} = @type_node.process(env)
    array_type = new env.types.Array(type)
    {env: new_env, type: array_type} 

class TupleType
  constructor: (@types) ->
  process: (env) ->
    tuple_types = for t in @types
      {env, type} = t.process(env)
      type
    type = new types.Tuple(tuple_types) 
    {env, type}

class RecordType
  constructor: (pairs) -> 
    @namespace = _(pairs).mash((obj) -> [obj.key, obj.value])
  type: (env) -> @process(env).type
  process: (env) ->
    record_types = for name, type_node of @namespace
      {env, type} = type_node.process(env)
      [name, type]
    record_type = new types.Record(_.mash(record_types))
    {env, type: record_type}

class FunctionType
  constructor: (@args, @result) ->
  type: (env) -> @process(env).type
  process: (env) ->
    arg_types = for arg in @args 
      {env, type} = arg.process(env)
      type
    type_args = new types.Tuple(arg_types)
    {env, type: type_result} = @result.process(env)
    function_type = new types.Function(type_args, type_result)
    {env, type: function_type}

# Standard values
  
class Int
  constructor: (@value_token) ->
  process: (env) -> {env, type: new env.types.Int}
  compile: (env) -> @value_token

class Float
  constructor: (@value_token) ->
  process: (env) -> {env, type: new env.types.Float}
  compile: (env) -> @value_token

class String
  constructor: (string_token) -> @value = eval(string_token)
  process: (env) -> {env, type: new env.types.String}
  compile: (env) -> JSON.stringify(@value)

class Arr
  constructor: (@values) ->
  process: (env) ->
    array_type = if _.isNotEmpty(@values)
      type1 = @values[0].process(env).type
      for value in _.rest(@values)
        type2 = value.process(env).type
        if not type1.matchType(type2)
          error("TypeError", "found a value with type #{value.compile(env)}"+
                             ":#{type2} in array [#{type1}]")
      new env.types.Array(type1)
    else
      new env.types.Array
    {env, type: array_type}    
  compile: (env) -> 
    "[" + _(@values).invoke("compile").join(', ') + "]"

class Tuple
  constructor: (@values) ->
  process: (env) ->
    tuple_type = new types.Tuple(lib.getTypes(@values, env).types)
    {env, type: tuple_type}
  compile: (env) -> 
    "[" + _(@values).invoke("compile", env).join(", ") + "]" 

class Record
  constructor: (pairs) ->
    @namespace = _(pairs).mash((obj) -> [obj.key, obj.value])
  process: (env) -> 
    namespace = _(@namespace).mash((v, k) -> [k, v.type(env)])
    record_type = new types.Record(namespace)
    {env, type: record_type}
  compile: (env) -> 
    "{" + ("#{k}: #{v.compile(env)}" for k, v of @namespace).join(", ") + "}"

class RecordAccess
  constructor: (@record, @record_key) ->
  process: (env) ->
    record_type = @record.type(env)
    unless record_type instanceof types.Record
      error("NameError", "access to non-record expression: #{@record.compile(env)}") 
    type = record_type.get(@record_key) or
      error("NameError", "undefined record key '#{@record_key}'")
    {env, type}
  compile: (env) ->
    "#{@record.compile(env)}.#{@record_key}"
   
# Misc

class Comment
  constructor: (@comment) ->
  process: (env) -> {env}
  compile: (env) -> "// #{@comment}" 

exports.FunctionCallFromID = (name, args) ->
  new FunctionCall(new Identifier(name), args)
 
lib.exportClasses(exports, [
  Function, FunctionCall, DefArg, Expression, StatementExpression, If,
  Identifier, Binding, Int, String, Arr, Type, ArrType, NewType,
  TypeConstructor, Root, Comment, Tuple, TupleType, Float, Block, ParenExpression,
  External, FunctionType, TypeConstructorDefinition, Record, RecordType, 
  RecordAccess, TypeVariable, StatementIf, Return, Range, OpenRange,
  UnaryOp,
])
