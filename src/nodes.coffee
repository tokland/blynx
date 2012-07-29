lib = require './lib'
types = require './types'
_ = require('./underscore_extensions')
{error, debug} = lib

translate_table =
  "=": "equal"
  "+": "plus"
  "-": "minus"
  "^": "circumflex"
  "~": "tilde" 
  "<": "less"
  ">": "more"
  "!": "exclamation",
  ":": "colon"
  "*": "mul"
  "/": "div"
  "%": "percent"
  "&": "ampersand"
  "|": "pipe"
 
valid_varname = (s) ->
  ((if translate_table[c] then "__#{translate_table[c]}" else c) for c in s).join("") 

exports.FunctionCallFromID = (name, args, options = {}) ->
  name2 = if options.unary then "#{name}_unary" else name
  args2 = (new FunctionArgument("", arg) for arg in args)
  new FunctionCall(new Symbol(name2), args2)

class Root
  constructor: (@nodes) ->
  compile_with_process: (env) ->
    output = for node in @nodes when node
      {env, type} = node.process(env)
      node.compile(env)
    {env, output: lib.indent(_(output).compact().join("\n"))}
    
## Statements

class SymbolBinding
  constructor: (@name, @block) ->
  process: (env) -> 
    type = @block.process(env).type
    {env: env.add_binding(@name, type), type}
  compile: (env) ->
    name = valid_varname(@name)
    if lib.getClass(@block) == Expression
      "var #{name} = #{@block.compile(env)};"
    else
      """
        var #{name} = (function() {>>
          #{@block.compile(env, return: true)}<<
        }).call(this);
      """

## Functions

class FunctionBinding
  constructor: (name, @args, @result_type, @block, options = {}) ->
    @name = if options.unary then "#{name}_unary" else name
  get_block_env: (env) ->
    block_env = _.freduce @args, env, (block_env, arg) ->
      block_env.add_binding(arg.name, arg.process(env).type, 
        error_msg: "argument '#{arg.name}' already defined in function binding")
  process: (env) ->
    block_env = @get_block_env(env)
    block_type = @block.process(block_env).type
    result_type = @result_type.process(env).type
    unless namespace = types.match_types(block_type, result_type)
      msg = "function '#{@name}' should return '#{result_type}' but returns '#{block_type}'"
      error("TypeError", msg)
    new_env = env.add_function_binding(@name, @args, result_type)
    {env: new_env, type: result_type}
  compile: (env) -> 
    block_env = @get_block_env(env)
    js_args = _(@args).pluck("name").join(', ')
    fname = valid_varname(@name)
    if lib.getClass(@block) == Block
      """
        var #{fname} = function(#{js_args}) {>>
          #{@block.compile(block_env, return: true)}<<
        };
      """
    else
      "var #{fname} = function(#{js_args}) { return #{@block.compile(block_env)}; };"

class TypedArgument
  constructor: (@name, @type) ->
  process: (env) -> {env, type: @type.process(env).type}

class Type
  constructor: (@name, @args) ->
  process: (env) ->
    type_args = env.get_types_from_nodes(@args)
    type = env.get_type(@name)
    {env, type: new type(type_args)}

class TypeVariable
  constructor: (@name) ->
  process: (env) -> {env, type: new types.Variable(@name)}

class TupleType
  constructor: (@types) ->
  process: (env) ->
    tuple_args = env.get_types_from_nodes(@types)
    {env, type: new types.Tuple(tuple_args)}

class FunctionType
  constructor: (@args, @result) ->
  process: (env) ->
    args = new types.NamedTuple(["", t] for t in env.get_types_from_nodes(@args))
    result = @result.process(env).type
    {env, type: new types.Function(args, result)}

## Expressions

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> @value.compile(env)

class ParenExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "(" + @value.compile(env) + ")"

class Block
  constructor: (@nodes) ->
  process: (env, options = {}) ->
    _(@nodes).isNotEmpty() or error("SyntaxError", "Empty block")
    for node in @nodes
      {env, type} = node.process(env, options)
    {env, type}
  compile: (env, options = {}) ->
    _(options).defaults(return: false)
    compiled = _(@nodes).invoke("compile", env)
    last_expr = _.last(compiled)
    tail = if options.return then ["return #{last_expr}"] else [last_expr]
    _(compiled[0...-1]).concat(tail).join("\n")

class StatementExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "#{@value.compile(env)};"
  
class Symbol
  constructor: (@name) ->
  process: (env) -> {env, type: env.get_binding(@name)}
  compile: (env) -> valid_varname(@name)

class FunctionArgument
  constructor: (@name, @value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> @value.compile(env)

class FunctionCall
  constructor: (@name, @args) ->
  process: (env) ->
    check_function_type = (function_type) =>
      unless lib.getClass(function_type) == types.Function
        error("TypeError", "binding '#{function_type}' called, but it's not a function")
    check_repeated_arguments = =>       
      keys = (arg.name for arg in @args)
      repeated_keys = (k for k, ks of _.groupBy(keys, _.identity) when k and ks.length > 1)
      if (repeated_key = _.first(repeated_keys))
        error("ArgumentError", "function call repeats argument '#{repeated_key}'")
    check_arguments_size = (function_type) =>
      size = _.size(function_type.args.get_types())
      if _.size(@args) != size
        msg = "function '#{@name.compile(env)}' takes #{size} arguments but #{@args.length} given"
        error("ArgumentError", msg)
    match_types = (function_type) =>
      function_args = function_type.args
      result = function_type.result
      given_args = new types.NamedTuple([a.name, a.process(env).type] for a in @args)
      merged = function_args.merge(given_args)
      namespace = types.match_types(function_args, merged) or
        error("TypeError", "function '#{function_type}', called with arguments '#{merged}'")
      result.join(namespace)

    function_type = @name.process(env).type
    check_function_type(function_type)
    check_repeated_arguments()
    check_arguments_size(function_type)
    type = match_types(function_type)
    {env, type}
  compile: (env) ->
    key_to_index = _.mash([k, i] for [k, v], i in @name.process(env).type.args.args)
    sorted_args = _.sortBy(@args, (arg) -> parseInt(key_to_index[arg.name]))
    valid_varname(@name.compile(env)) + 
      "(" + _(sorted_args).invoke("compile", env).join(', ') + ")"

## Literals
  
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

class Tuple
  constructor: (@values) ->
  process: (env) ->
    args = env.get_types_from_nodes(@values)
    {env, type: new env.types.Tuple(args)}
  compile: (env) ->
    "[" + _(@values).invoke("compile", env).join(", ") + "]" 

##

class TypeDefinition
  constructor: (@name, @args, @constructors) ->
  process: (env) ->
    args = env.get_types_from_nodes(@args)
    type = types.buildType(@name, @args.length)
    env_with_type = env.add_type(@name, type)
    new_env = _.freduce @constructors, env_with_type, (e, constructor) ->
      constructor.add_binding(e, type, args)
    {env: new_env}
  compile: (env) ->
    "// type #{@name}\n" +
      _(@constructors).invoke("compile", env).join("\n") + "\n"

class TypeConstructorDefinition
  constructor: (@name, @args) ->
  compile: (env) ->
    if _(@args).isEmpty()
      "var #{@name} = {};"
    else
      names = _(@args).pluck("name")
      val = "{" + ("#{JSON.stringify(n)}: #{n}" for n in names) + "}"
      "var #{@name} = function(#{names.join(', ')}) { return #{val}; };"
  add_binding: (env, type, type_args) ->
    binding_type = if _(@args).isEmpty()
      env.add_binding(@name, new type(type_args)) 
    else
      env.add_function_binding(@name, @args, new type(type_args))

##

class Comment
  constructor: (@text) ->
  process: (env) -> {env}
  compile: (env) -> "// #{@text}"

##

lib.exportClasses(exports, [
  Root
  SymbolBinding, FunctionBinding, 
  TypedArgument, Type, TypeVariable, 
  TupleType, FunctionType
  Expression, ParenExpression, Block, StatementExpression
  Symbol, 
  FunctionCall, FunctionArgument
  Int, Float, String, Tuple
  TypeDefinition, TypeConstructorDefinition
  Comment
])

exports.node = (class_name, args...) ->
  klass = exports[class_name] or
    error("InternalError", "Cannot find node '#{class_name}'")
  new klass(args...)
