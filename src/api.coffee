#!/usr/bin/coffee
_ = require 'underscore_extensions'

error = (type, msg) ->
  throw new Error("#{type}: #{msg}")

extend = (obj, obj2) ->
  obj[k] = v for k, v of obj2

merge = (obj, obj2) ->
  output = {}
  extend(output, obj)
  extend(output, obj2)
  output

wrap = (fn) ->
  (args...) -> fn()(args...)

range = (cons, nil, start, end, inclusive, step) ->
  xs = if inclusive
    (x for x in [start..end] by step)
  else
    (x for x in [start...end] by step)
  _.reduceRight(xs, ((acc_list, x) -> cons(x, acc_list)), nil)
    
match = (matchable, value) ->
  if matchable.kind == "Tuple"
    matches = (match(m, v) for [m, v] in _.zip(matchable.value, value))
    _.freduce(matches, {}, _.merge)
  else if matchable.kind in ["Int", "Float", "String"]
    if matchable.value != value
      error("RuntimeError", "Values do not match: #{matchable.value} != #{value}") 
  else if matchable.kind == "symbol"
    _.mash([[matchable.name, value]])
  else if matchable.kind == "adt"
    if matchable.name != value._name 
      error("RuntimeError", "Values do not match: #{matchable.name} != #{value._name}")
    matches = (match(arg.value, value[arg.name]) for arg in matchable.args)
    _.freduce(matches, {}, _.merge)
  else if matchable.kind == "list"
    start = {result: {}, list: value}
    {result, list} = _.freduce matchable.values, start, ({result, list}, mvalue) -> 
      {head, tail} = list
      if not tail
        error("RuntimeError", "Cannot match list: pattern too long")
      new_result = _(result).merge(match(mvalue, head))
      {result: new_result, list: tail} 
    if matchable.tail
      _(result).merge(_.mash([[matchable.tail, list]])) 
    else
      if list._name != "Nil"
        error("RuntimeError", "Cannot match list: pattern too short")
      result
  else
    error("InternalError", "Matchable kind '#{matchable.kind}' not implemented")
  
exports.merge = merge
exports.extend = extend
exports.wrap = wrap
exports.match = match
exports.range = range
