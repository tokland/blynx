vm = require 'vm'
_ = require('./underscore_extensions')
types = require './types'
lexer = require('./lexer')
nodes = require('./nodes')
grammar = require('./grammar')
lib = require './lib'
{debug, error} = lib

class Binding
  constructor: (@type) ->

class Environment
  constructor: (@bindings, @types, @function = []) ->
  add_binding: (name, type) ->
    @bindings[name] and
      error("BindingError", "Symbol '#{name}' alread bound to type '#{@bindings[name]}'")
    new_bindings = _.merge(@bindings, _.mash([[name, type]]))
    new Environment(new_bindings, @types, @function)
  get_binding: (name) ->
    @bindings[name] or
      error("NameError", "undefined symbol '#{name}'")

## Functions

getParser = (options) ->
  _(grammar.parser).merge
    yy: nodes
    lexer:
      lex: ->
        [name, @yytext, @yylineno] = 
          if @tokens.length > @pos then @tokens[@pos++] else ['EOF', "", ""]
        name
      setInput: (tokens) ->
        @tokens = tokens
        @pos = 0
    parseError: (msg, hash) ->
      msg = "Unexpected token '#{hash.token}' on line #{hash.line}" + 
        (if hash.expected then " (expecting: #{hash.expected})" else "")
      error("ParserError: #{msg}")

exports.getAST = getAST = (source, options = {}) ->
  parser = getParser(debug: options.verbose)
  tokens = lexer.tokenize(source)
  parser.parse(tokens)

exports.compile = compile = (source, options = {}) ->
  get_basic_types = (names) -> _(names).mash((name) -> [name, types[name]])
  types = get_basic_types(["Int", "Float", "String", "Tuple"])
  env = new Environment({}, types) 
  {env: final_env, output} = getAST(source, options).compile_with_process(env)
  output + "\n"
  
exports.run = (source, options = {}) ->
  output = compile(source, options)
  sandbox = {api: require('./api'), console: console}
  vm.runInNewContext(output, sandbox)
