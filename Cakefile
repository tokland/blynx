sys = require 'sys'
fs = require 'fs'
{spawn, exec} = require 'child_process'

run = (args, env) ->
  coffee = spawn args[0], args[1..-1]
  coffee.stdout.on 'data', (data) -> sys.print(data.toString())
  coffee.stderr.on 'data', (data) -> sys.print(data.toString())  

build = ->
  run ['coffee', '-c', '-o', 'lib', 'src']

task 'build', 'Compile main project', ->
  build()

task 'grammar', 'Compile language grammar', ->
  build()
  grammar = require 'grammar'
  filename = 'lib/parser.js'
  fs.writeFile(filename, grammar.parser.generate())
  sys.print("Parser grammar created: #{filename}\n")
    
task 'specs', 'Run specs', ->
  process.env["NODE_PATH"] = "src:lib"
  run(['node_modules/jasmine-node/bin/jasmine-node', "--coffee", "spec"], process.env)

task 'autospec', 'Run specs', ->
  process.env["NODE_PATH"] = "src:lib"
  run(['node_modules/jasmine-node/bin/jasmine-node', "--coffee", "--autotest", "spec"], process.env)
