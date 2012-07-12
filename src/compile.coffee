#!/usr/bin/coffee
yanop = require 'yanop'
fs = require 'fs'
vm = require 'vm'
util = require 'util'
path = require 'path'

_ = require('./underscore_extensions')
lexer = require('./lexer')
grammar = require('./grammar')
nodes = require('./nodes')
lib = require('./lib')
types = require './types'
{error, debug} = lib

prelude_source = fs.readFileSync(path.join(__dirname, "prelude.kr"), "utf8")

exports.getParser = getParser = (grammar, options) ->
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

exports.compile = compile = (parser, source, options = {}) ->
  get_basic_types = (names) -> _(names).mash((name) -> [name, types[name]])  
  env = {
    bindings: {}
    types: get_basic_types(["Int", "Float", "String", "Array"])
    typevars: {}
    current_function: undefined
  }

  #{env: env, output: output1} = getAST(parser, prelude_source, options).compile_with_process(env)
  {env: env, output: output1} = getAST(parser, source, options).compile_with_process(env)
  #output = (if options.skip_prelude then "" else (output1 + "\n\n")) + output2
  {env: env, output: output1}

if not module.parent
  options = yanop.simple({
    verbose: {type: yanop.flag, short: 'v', long: "verbose"}
    tokens: {type: yanop.flag, short: 't', long: "tokens"}
    print: {type: yanop.flag, short: 'p', long: "print"}
    ast: {type: yanop.flag, short: 'a', long: "ast"}
    standalone: {type: yanop.flag, short: 's', long: "standalone"}
    compile: {type: yanop.flag, short: 'c', long: "compile"}
    repl: {type: yanop.flag, short: 'r', long: "repl", default: true}
  })
  
  args = options.argv
  if _(args).isEmpty()
    util.print("Usage: compile.coffee KRYPTON_FILE\n")
    process.exit(1)
  for source_path in args
    source = fs.readFileSync(source_path, "utf8")
    if options.tokens
      tokens = lexer.tokenize(source)
      util.print(lib.simpleTokens(tokens) + "\n")
      process.exit(0)
      
    parser = getParser(grammar, debug: options.verbose)
    {env, output} = compile(parser, source, 
      debug: options.verbose, skip_prelude: !options.standalone)
    if options.verbose
      debug("[ENVIRONMENT]\n", env, "\n---")
      
    dependencies = """
      api = require('api');
      // api.update(globals, require('prelude'));
    """

    if options.print
      #util.print([dependencies, output].join("\n\n") + "\n")
      util.print(output+"\n")
      process.exit(0)
    else if options.compile
      contents = [dependencies, output].join("\n\n") + "\n"
      jspath = source_path.replace(/\.\w+/, '.js')
      fs.writeFileSync(jspath, contents, "utf8")
      debug("Written to file: #{jspath}") 
    else if options.ast
      ast = getAST(parser, source)
      util.print(ast + "\n") # add pretty print of AST nodes
    else
      sandbox = {api: require('./api'), console: console}
      vm.runInNewContext(output, sandbox)
