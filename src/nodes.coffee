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
 
translateFunctionName = (s) ->
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
    name = translateFunctionName(@name)
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
  process: (env) ->
    block_env = _.freduce @args, env, (block_env, arg) ->
      block_env.add_binding(arg.name, arg.process(env).type, 
        error_msg: "argument '#{arg.name}' already defined in function binding")
    block_type = @block.process(block_env).type
    result_type = @result_type.process(env).type
    if not types.isSameType(result_type, block_type)
      error("TypeError",
        "function '#{@name}' should return '#{result_type}' but returns '#{block_type}'")
    new_env = env.add_function_binding(@name, @args, result_type)
    {env: new_env, type: result_type}
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

class TypedArgument
  constructor: (@name, @type) ->
  process: (env) -> {env, type: @type.process(env).type}

class Type
  constructor: (@name) ->
  process: (env) -> 
    {env, type: new(env.get_type(@name))}

class TupleType
  constructor: (@types) ->
  process: (env) ->
    type = new types.Tuple(lib.getTypes(@types, env).types)
    {env, type: type}

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
  constructor: (@id_token) ->
  process: (env) -> {env, type: env.get_binding(@id_token)}
  compile: (env) -> @id_token

class FunctionArgument
  constructor: (@name, @value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> @value.compile(env)

class FunctionCall
  constructor: (@name, @args) ->
  process: (env) ->
    function_type = @name.process(env).type
    expected_args = function_type.fargs
    check_arguments_size = =>
      size = _.size(expected_args.getTypes())
      if _.size(@args) != size
        msg = "function '#{@name.compile(env)}' takes #{size} arguments but #{@args.length} given"
        error("ArgumentError", msg)
    check_repeated_arguments = =>       
      keys = (arg.name for arg in @args)
      repeated_keys = (k for k, ks of _.groupBy(keys, _.identity) when k and ks.length > 1)
      if (repeated_key = _.first(repeated_keys))
        error("ArgumentError", "function call repeats argument '#{repeated_key}'")
    match_types = =>
      given_args = new types.NamedTuple([a.name, a.process(env).type] for a in @args)
      merged = types.mergeNamedTuples(expected_args, given_args)
      if not types.isSameType(expected_args, merged)
        error("TypeError", "function '#{function_type}', called with arguments '#{merged}'")
        
    check_arguments_size()
    check_repeated_arguments()
    match_types()
    {env, type: function_type.result}
  compile: (env) ->
    key_to_index = _.mash([k, i] for [k, v], i in @name.process(env).type.fargs.types)
    sorted_args = _.sortBy(@args, (arg) -> parseInt(key_to_index[arg.name]))
    translateFunctionName(@name.compile(env)) + 
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
    {env, type: new env.types.Tuple(lib.getTypes(@values, env).types)}
  compile: (env) ->
    "[" + _(@values).invoke("compile", env).join(", ") + "]" 

##

class TypeDefinition
  constructor: (@name, @constructors) ->
  process: (env) ->
    type = types.buildType(@name)
    env_with_type = env.add_type(@name, type)
    new_env = _.freduce @constructors, env_with_type, (e, constructor) ->
      constructor.add_binding(e, type)
    {env: new_env, type: new type}
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
  add_binding: (env, type) ->
    binding_type = if _(@args).isEmpty()
      env.add_binding(@name, new type) 
    else
      env.add_function_binding(@name, @args, new type)

##

lib.exportClasses(exports, [
  Root
  SymbolBinding, FunctionBinding, TypedArgument, 
  Type, TupleType
  Expression, ParenExpression, Block, StatementExpression
  Symbol, FunctionCall, FunctionArgument
  Int, Float, String
  Tuple
  TypeDefinition, TypeConstructorDefinition
])

exports.node = (class_name, args...) ->
  klass = exports[class_name] or
    error("InternalError", "Cannot find node '#{class_name}'")
  new klass(args...)
