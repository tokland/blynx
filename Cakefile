sys = require 'sys'
fs = require 'fs'
{spawn, exec} = require 'child_process'

task 'build', 'Compile main project', ->
  invoke('grammar')
  build()
  invoke('specs')

task 'grammar', 'Compile language grammar', ->
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
  
run = (args, env) ->
  coffee = spawn(args[0], args[1..-1])
  cb = (data) -> sys.print(data.toString())
  coffee.stdout.on('data', cb)
  coffee.stderr.on('data', cb)  

build = ->
  run(['coffee', '-c', '-o', 'lib', 'src'])
