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
  inspect: ->
    bindings = ("    #{k}: #{v}" for k, v of @bindings).join("\n")
    "Environment:\n" + 
      "  Types: " + _.keys(@types).join(", ") + "\n" + 
      "  Bindings: " + (if _(@bindings).isEmpty() then "none" else "\n"+bindings) + "\n"
  add_binding: (name, type, options = {}) ->
    if @bindings[name]
      msg = options.error_msg or "symbol '#{name}' already bound to type '#{@bindings[name]}'"  
      error("BindingError", msg)
    new_bindings = _.merge(@bindings, _.mash([[name, type]]))
    new Environment(new_bindings, @types, @function)
  get_binding: (name) ->
    @bindings[name] or
      error("NameError", "undefined symbol '#{name}'")
  add_type: (name, type) ->
    @types[name] and
      error("TypeError", "type '#{name}' already defined")
    new_types = _.merge(@types, _.mash([[name, type]]))
    new Environment(@bindings, new_types, @function)
  get_type: (name) ->
    @types[name] or
      error("TypeError", "undefined type '#{name}'")
  add_function_binding: (name, args, result_type) ->
    args_ns = ([arg.name, arg.process(this).type] for arg in args)
    args_type = new types.NamedTuple(args_ns)
    function_type = new types.Function(args_type, result_type)
    @add_binding(name, function_type)

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
      error("ParserError", msg)

exports.getAST = getAST = (source, options = {}) ->
  parser = getParser(debug: options.verbose)
  tokens = lexer.tokenize(source)
  parser.parse(tokens)

exports.compile = compile = (source, options = {}) ->
  get_basic_types = (names) -> 
    _(names).mash((name) -> [name, types[name]])
  basic_types = get_basic_types(["Int", "Float", "String", "Tuple"])
  env = new Environment({}, basic_types)
  {env: final_env, output} = getAST(source, options).compile_with_process(env)
  process.stderr.write(final_env.inspect()+"\n") if options.debug 
  output + "\n"
  
exports.run = (source, options = {}) ->
  output = compile(source, options)
  sandbox = {api: require('./api'), console: console}
  vm.runInNewContext(output, sandbox)
