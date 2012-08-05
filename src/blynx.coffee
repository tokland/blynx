#!/usr/bin/coffee
yanop = require 'yanop'
fs = require 'fs'
util = require 'util'
path = require 'path'
_ = require('./underscore_extensions')
lexer = require('./lexer')
compiler = require('./compiler')
lib = require('./lib')
{error, debug} = lib

compile = (source, options) ->
  compiler.compile(source, debug: options.verbose)

run = (source, options) ->
  compiler.run(source, debug: options.verbose)

## Main

flag = (opts) -> _.merge({type: yanop.flag}, opts)
options = yanop.simple
  # modes
  run:        flag(short: 'r', long: "run", default: true)
  tokens:     flag(short: 't', long: "tokens")
  print:      flag(short: 'p', long: "print")
  ast:        flag(short: 'a', long: "ast")
  compile:    flag(short: 'c', long: "compile")
  interactie: flag(short: 'i', long: "interactive")
  # options
  verbose:    flag(short: 'v', long: "verbose")
  
args = options.argv

if _(args).isEmpty()
  util.print("Usage: blynx [OPTIONS] SOURCE [SOURCE ...]\n")
  process.exit(1)

for source_path in args
  source = fs.readFileSync(source_path, "utf8")
  
  if options.tokens
    tokens = lexer.tokenize(source)
    util.print(lib.simpleTokens(tokens) + "\n")
    process.exit(0)
  else if options.print
    output = compile(source, options).output
    util.print(output)
    process.exit(0)
  else if options.compile
    output = compile(source, options).output
    jspath = source_path.replace(/\.\w+/, '.js')
    fs.writeFileSync(jspath, output, "utf8")
    debug("Written to file: #{jspath}")
  else if options.ast
    ast = compiler.getAST(source)
    past = compiler.pretty_ast(ast)
    util.print(JSON.stringify(past, null, 2) + "\n") 
  else if options.run
    run(source, options)
