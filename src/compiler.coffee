vm = require 'vm'
_ = require 'underscore_extensions'
types = require 'types'
lexer = require 'lexer'
nodes = require 'nodes'
jison_parser = require 'parser'
environment = require 'environment'
lib = require 'lib'
{debug, error, indent} = lib
   
##

getParser = (options) ->
  _(jison_parser.parser).merge
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
  env = _(["Int", "Float", "String"]).freduce new environment.Environment, (e, name) ->
    e.add_type(name, types[name], [])
  {env: final_env, output} = getAST(source, options).compile_with_process(env)
  process.stderr.write(final_env.inspect()+"\n") if options.debug
  complete_output = "api = require('api');\n\n" + output + "\n" 
  {env: final_env, output: complete_output}
  
exports.run_js = run_js = (jscode, base_context = null) ->  
  sandbox = {require: require, escape: escape}
  context = base_context or vm.createContext(sandbox)
  value = vm.runInContext(jscode, context)
  {context, value}
  
exports.pretty_ast = pretty_ast = (node) ->
  name = lib.getClass(node).name 
  values = for k, v of node
    value = switch v.constructor.name
      when "Function" then null
      when "Array" then (pretty_ast(x) for x in v) 
      when "String" then v
      else pretty_ast(v)
    if value then [k, value] else null
  [name, _.compact(values)]

exports.run = (source, options = {}) ->
  output = compile(source, options).output
  run_js(output)
