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

class SymbolBinding
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

# Expressions

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  type: (env) -> @process(env).type
  compile: (env) -> @value.compile(env)
  
class Symbol
  constructor: (@id_token) ->
  process: (env) ->
    if not env.bindings[@id_token]
      error("NameError", "undefined symbol '#{@id_token}'")
    {env, type: env.bindings[@id_token]}
  compile: (env) -> @id_token

# Literals
  
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

lib.exportClasses(exports, [
  Root, 
  SymbolBinding, 
  Expression, 
  Symbol, 
  Int, Float, String
])
