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
  
runtime_error = (msg) ->
  error("RuntimeError", msg)
    
match_error = runtime_error

match = (matchable, value, options = {}) ->
  if options.return_value
    try
      _match(matchable, value)
    catch error
      false
  else
    _match(matchable, value)
  
_match = (matchable, value) ->
  if matchable.kind == "Tuple"
    matches = (_match(m, v) for [m, v] in _.zip(matchable.value, value))
    _.freduce(matches, {}, _.merge)
  else if matchable.kind in ["Int", "Float", "String"]
    if matchable.value != value
      match_error("Cannot match values: #{matchable.value} != #{value}")
    else
      {} 
  else if matchable.kind == "symbol"
    _.mash([[matchable.name, value]])
  else if matchable.kind == "adt"
    if matchable.name != value._name
      match_error("Cannot match constructors: #{matchable.name} != #{value._name}")
    else 
      matches = (_match(arg.value, value[arg.name]) for arg in matchable.args)
      _.freduce(matches, {}, _.merge)
  else if matchable.kind == "list"
    start = {result: {}, list: value}
    {result, list} = _.freduce matchable.values, start, ({result, list}, mvalue) -> 
      {head, tail} = list
      if not tail
        match_error("Cannot match list: pattern too long")
      else
        new_result = _(result).merge(_match(mvalue, head))
        {result: new_result, list: tail} 
    if matchable.tail
      _(result).merge(_.mash([[matchable.tail, list]])) 
    else
      if list._name != "Nil"
        match_error("Cannot match list: pattern too short")
      else
        result
  else
    error("InternalError", "Matchable kind '#{matchable.kind}' not implemented")
  
exports.merge = merge
exports.extend = extend
exports.wrap = wrap
exports.match = match
exports.range = range
exports.runtime_error = runtime_error
