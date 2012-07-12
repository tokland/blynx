_ = require('./underscore_extensions')
types = require './types'
lexer = require('./lexer')
nodes = require('./nodes')
grammar = require('./grammar')
lib = require './lib'
{debug, error} = lib

getParser = (options) ->
  _(grammar.parser).merge({
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
      msg = "Unexpected token '#{hash.token}' on line #{hash.line} (expecting: #{hash.expected})"
      error("ParserError: #{msg}")
  })

exports.getAST = getAST = (source, options = {}) ->
  parser = getParser(debug: options.verbose)
  tokens = lexer.tokenize(source)
  parser.parse(tokens)

exports.compile = (source, options = {}) ->
  get_basic_types = (names) -> _(names).mash((name) -> [name, types[name]])  
  env = { # create class/type
    bindings: {} # -> call it symbols
    types: get_basic_types(["Int", "Float", "String"])
    current_function: []
  }
  getAST(source, options).compile_with_process(env).output + "\n"
