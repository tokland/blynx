{print} = require 'sys'
{spawn, exec} = require 'child_process'

run = (args, env) ->
  coffee = spawn args[0], args[1..-1]
  coffee.stdout.on 'data', (data) -> print data.toString()
  coffee.stderr.on 'data', (data) -> print data.toString()  

build = ->
  run ['coffee', '-c', '-o', 'lib', 'src']

task 'build', 'Compile main project', ->
  build()

task 'grammar', 'Compile language grammar', ->
  build()
  grammar = require './lib/grammar'
  parser = grammar.getParser(debug: true)
  parser.generate()
  
task 'specs', 'Run specs', ->
  process.env["NODE_PATH"] += ":src"
  process.env["BLYNX_PATH"] = "spec/modules"
  run(['node_modules/jasmine-node/bin/jasmine-node', "--coffee", "spec"], process.env)

task 'autospec', 'Run specs', ->
  process.env["NODE_PATH"] += ":lib"
  process.env["BLYNX_PATH"] = "spec/modules"
  run(['node_modules/jasmine-node/bin/jasmine-node', "--coffee", "--autotest", "spec"], process.env)
