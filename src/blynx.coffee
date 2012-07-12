#!/usr/bin/coffee
yanop = require 'yanop'
fs = require 'fs'
vm = require 'vm'
util = require 'util'
path = require 'path'

_ = require('./underscore_extensions')
lexer = require('./lexer')
grammar = require('./grammar')
compiler = require('./compiler')
lib = require('./lib')
types = require './types'
{error, debug} = lib

prelude_source = fs.readFileSync(path.join(__dirname, "prelude.kr"), "utf8")

## Main

if not module.parent
  flag = (opts) -> _.merge({type: yanop.flag}, opts)
  options = yanop.simple({
    verbose:    flag(short: 'v', long: "verbose")
    tokens:     flag(short: 't', long: "tokens")
    print:      flag(short: 'p', long: "print")
    ast:        flag(short: 'a', long: "ast")
    standalone: flag(short: 's', long: "standalone")
    compile:    flag(short: 'c', long: "compile")
    repl:       flag(short: 'r', long: "repl")
  })
  args = options.argv
  
  if _(args).isEmpty()
    util.print("Usage: blynx [OPTIONS] source.bl\n")
    process.exit(1)
    
  for source_path in args
    source = fs.readFileSync(source_path, "utf8")
    if options.tokens
      tokens = lexer.tokenize(source)
      util.print(lib.simpleTokens(tokens) + "\n")
      process.exit(0)
      
    parser = compiler.getParser(grammar, debug: options.verbose)
    {env, output} = compiler.compile(parser, source, 
      debug: options.verbose, skip_prelude: !options.standalone)
    if options.verbose
      debug("[ENVIRONMENT]\n", env, "\n---")
      
    dependencies = """
      // api = require('api');
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
      ast = compiler.getAST(parser, source)
      util.print(ast + "\n") # add pretty print of AST nodes
    else
      sandbox = {api: require('./api'), console: console}
      vm.runInNewContext(output, sandbox)
