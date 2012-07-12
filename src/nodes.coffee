lib = require './lib'
_ = require('./underscore_extensions')

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

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  type: (env) -> @process(env).type
  compile: (env) -> @value.compile(env)
  
class Symbol
  constructor: (@id_token) ->
  process: (env) ->
    if not env.bindings[@id_token]
      error("NameError", "undefined Symbol '#{@id_token}'")
    {env, type: env.bindings[@id_token]}
  compile: (env) -> @id_token

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

exports.FunctionCallFromID = (name, args) ->
  new FunctionCall(new Symbol(name), args)
 
lib.exportClasses(exports, [
  Root, Expression, Symbol, Binding, Int, Float, String
])
