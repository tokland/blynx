#!/usr/bin/coffee
_ = require './underscore_extensions'

# Common

exports.debug = (args...) -> 
  console.error.apply(this, args)

exports.error = (type, msg) ->
  throw new Error("#{type}: #{msg}")

exports.exportClasses  = (_exports, klasses) ->
  for klass in klasses
    _exports[klass.name] = klass  

# Lexer

exports.simpleTokens = (tokens) ->
  _(tokens).map((token) ->
    [k, s, line] = token
    #if k == "INDENT"
    if s && k != s then "[#{k} #{s}]" else k
  ).join(" ")

# Types

exports.zipEqType = (array1, array2) ->
  (array1.length == array2.length) &&
    _.all(_(array1).zip(array2), ([a1, a2]) -> a1.eqType(a2))

# Grammar

unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

exports.createGrammarItem = o = (patternString, action, options) ->
  patternString = patternString.replace(/\s{2,}/g, ' ')
  if action
    match = unwrap.exec action
    action = (if match then match[1] else "(#{action}())").
      replace(/\bnew /g, '$&yy.').
      replace(/\b(?:Block\.wrap|extend)\b/g, 'yy.$&')
    [patternString, "$$ = #{action};", options]
  else
    [patternString, '$$ = $1;', options]

exports.recursiveGrammarItem = (rule, options) ->
  _(options).defaults(min: 1, join: null)
  join = options.join
  _.compact([
    (o("", -> []) if options.min == 0)
    o(rule, -> [$1])
    if join then o("#{rule}List #{join} #{rule}", -> $1.concat($3)) else 
                 o("#{rule}List #{rule}", -> $1.concat($2))
  ])

# Nodes

exports.getTypes = (values, env) ->
  types = for value in values
    {env, type} = value.process(env)
    type
  {env, types}

exports.indent = (source) -> 
  _(source.split(/\n/)).freduce({indent: 0, output: []}, (state, original_line) ->
    indentation = _.repeat("  ", state.indent).join("")
    line = indentation + original_line.trim().replace(/(>>|<<)\s*$/, '')
    new_indent = if original_line.match(">>\s*$")
      state.indent + 1
    else if original_line.match("<<\s*$")
      state.indent - 1
    else 
      state.indent
      
    _(state).merge
      indent: new_indent
      output: (state.output.push(line); state.output)
  ).output.join("\n")
  
exports.getClass = (obj) -> obj.constructor

exports.optionalParens = (name, args) ->
  name + (if _(args).isNotEmpty() then "(" + args.join(', ') + ")" else "")
