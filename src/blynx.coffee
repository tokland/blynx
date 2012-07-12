#!/usr/bin/coffee
yanop = require 'yanop'
fs = require 'fs'
vm = require 'vm'
util = require 'util'
path = require 'path'
_ = require('./underscore_extensions')
lexer = require('./lexer')
compiler = require('./compiler')
lib = require('./lib')
{error, debug} = lib

compile = (source, options) ->
  compiler.compile(source, debug: options.verbose, skip_prelude: !options.standalone)

## Main

flag = (opts) -> _.merge({type: yanop.flag}, opts)
options = yanop.simple
  run:        flag(short: 'r', long: "repl", default: true)
  verbose:    flag(short: 'v', long: "verbose")
  tokens:     flag(short: 't', long: "tokens")
  print:      flag(short: 'p', long: "print")
  ast:        flag(short: 'a', long: "ast")
  standalone: flag(short: 's', long: "standalone")
  compile:    flag(short: 'c', long: "compile")
  interactie: flag(short: 'i', long: "interactive")
args = options.argv

if _(args).isEmpty()
  util.print("Usage: blynx [OPTIONS] SOURCE.bl [SOURCE2.bl ...]\n")
  process.exit(1)

for source_path in args
  source = fs.readFileSync(source_path, "utf8")
  
  if options.tokens
    tokens = lexer.tokenize(source)
    util.print(lib.simpleTokens(tokens) + "\n")
    process.exit(0)
  else if options.ast
    ast = compiler.getAST(parser, source)
    util.print(ast + "\n") # add pretty print of AST nodes
    process.exit(0)
  else if options.print
    output = compile(source, options)
    util.print(output)
    process.exit(0)
  else if options.compile
    output = compile(source, options)
    jspath = source_path.replace(/\.\w+/, '.js')
    fs.writeFileSync(jspath, output, "utf8")
    debug("Written to file: #{jspath}") 
  else if options.ast
    ast = compiler.getAST(parser, source)
    util.print(ast + "\n") # add pretty print of AST nodes
  else if options.run
    output = compile(source, options)
    sandbox = {api: require('./api'), console: console}
    vm.runInNewContext(output, sandbox)
