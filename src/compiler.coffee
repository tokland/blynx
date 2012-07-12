_ = require('./underscore_extensions')
types = require './types'
lexer = require('./lexer')
nodes = require('./nodes')
lib = require './lib'
{debug, error} = lib

exports.getParser = (grammar, options) ->
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

getAST = (parser, source, options = {}) ->
  tokens = lexer.tokenize(source)
  parser.parse(tokens)

exports.compile = (parser, source, options = {}) ->
  get_basic_types = (names) -> _(names).mash((name) -> [name, types[name]])  
  env = {
    bindings: {}
    types: get_basic_types(["Int", "Float", "String"])
    typevars: {}
    current_function: undefined
  }
  getAST(parser, source, options).compile_with_process(env)
