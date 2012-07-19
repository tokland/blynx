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
  new FunctionCall(new Symbol(name2), args)

class Root
  constructor: (@nodes) ->
  compile_with_process: (env) ->
    output = for node in @nodes when node
      {env, type} = node.process(env)
      node.compile(env)
    {env, output: lib.indent(_(output).compact().join("\n"))}
    
## Statements

class SymbolBinding
  constructor: (@id_token, @block) ->
  process: (env) -> 
    type = @block.process(env).type
    {env: env.add_binding(@id_token, type), type}
  compile: (env) ->
    if lib.getClass(@block) == Expression
      "var #{@id_token} = #{@block.compile(env)};"
    else
      """
        var #{@id_token} = (function() {>>
          #{@block.compile(env, return: true)}<<
        }).call(this);
      """

## Functions

class FunctionBinding
  constructor: (name, @args, @result_type, @block, options = {}) ->
    @name = if options.unary then "#{name}_unary" else name
  process: (env) ->
    args_type = new types.Tuple(lib.getTypes(@args, env).types)
    block_type = @block.process(env).type
    result_type = @result_type.process(env).type
    if not types.isSameType(result_type, block_type)
      error("TypeError", "function '#{@name}' expected to return '#{result_type}', but returns '#{block_type}'")
    function_type = new types.Function(args_type, result_type)
    {env: env.add_binding(@name, function_type), type: result_type}
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
    {env, type: new env.types[@name]}

## Expressions

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  type: (env) -> @process(env).type
  compile: (env) -> @value.compile(env)

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

class FunctionCall
  constructor: (@name, @args) ->
  process: (env) ->
    function_type = @name.process(env).type
    expected = function_type.fargs.types.length
    if @args.length != expected
      msg = "function '#{@name.compile(env)}' takes #{expected} arguments but #{@args.length} given"
      error("ArgumentsError", msg)
    expected = function_type.fargs
    given = new types.Tuple(a.process(env).type for a in @args)
    if not types.isSameType(expected, given)
      error("TypeError", "function '#{function_type}', called with arguments '#{given}'") 
    {env, type: function_type.result}
  compile: (env) ->
    name = @name.compile(env)
    translateFunctionName(@name.compile(env)) + "(" + _(@args).invoke("compile", env).join(', ') + ")"

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

lib.exportClasses(exports, [
  Root, 
  SymbolBinding, FunctionBinding, TypedArgument, Type 
  Expression, Block, StatementExpression, 
  Symbol, FunctionCall,
  Int, Float, String, 
  Tuple,
])

exports.node = (class_name, args...) ->
  klass = exports[class_name] or
    error("InternalError", "Cannot find node '#{class_name}'")
  new klass(args...)
