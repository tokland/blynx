#!/usr/bin/coffee
_ = require './underscore_extensions'

# Common

exports.debug = (args...) -> 
  console.error.apply(this, args)

exports.error = (type, msg) ->
  throw new Error("#{type}: #{msg}")

exports.exportClasses = (_exports, klasses) ->
  for klass in klasses
    _exports[klass.name] = klass
    
exports.indent = (nspaces, text) ->
  indentation = _.repeat(" ", nspaces).join("")
  indentation + text

# Lexer

exports.simpleTokens = (tokens) ->
  _(tokens).map(([name, string, line_number]) ->
    if string && name != string then "[#{name} #{string}]" else name
  ).join(" ")

# Grammar

unwrap = /^function\s*\(\)\s*\{\s*return\s*([\s\S]*);\s*\}/

exports.createGrammarItem = o = (patternString, action, options) ->
  patternString = patternString.replace(/\s{2,}/g, ' ')
  if action
    match = unwrap.exec(action)
    action = (if match then match[1] else "(#{action}())").
      replace(/\bnew (\w+)\(/g, 'new yy.node("$1", ').
      replace(/\b(?:Block\.wrap|extend)\b/g, 'yy.$&')
    [patternString, "$$ = #{action};", options]
  else
    [patternString, '$$ = $1;', options]

exports.recursiveGrammarItem = (rule, options = {}) ->
  _(options).defaults(min: 1, join: null, name: "#{rule}List")
  join = options.join
  rule_list = options.name
  _.compact([
    (o("", -> []) if options.min == 0)
    (o(rule, -> [$1]) if options.min <= 1)
    if join then o("#{rule_list} #{join} #{rule}", -> $1.concat($3)) \
            else o("#{rule_list} #{rule}", -> $1.concat($2))
  ])

# Nodes

exports.indent_code = (source) -> 
  _(source.split(/\n/)).freduce({indent: 0, output: []}, (state, original_line) ->
    indentation = _.repeat("  ", state.indent).join("")
    line = indentation + original_line.trim().replace(/(>>|<<)\s*$/, '')
    indent_increment = if original_line.match(">>\s*$") then +1
    else if original_line.match("<<\s*$") then -1
    else 0
    new_indent = state.indent + indent_increment
    state.output.push(line)
    _(state).merge(indent: new_indent, output: state.output)
  ).output.join("\n")
  
exports.getClass = (obj) -> 
  obj.constructor

exports.optionalParens = (name, args) ->
  name + (if _(args).isNotEmpty() then "(#{args.join(', ')})" else "")
