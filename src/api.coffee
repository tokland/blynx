#!/usr/bin/coffee
extend = (obj, obj2) ->
  obj[k] = v for k, v of obj2

merge = (obj, obj2) ->
  output = {}
  extend(output, obj)
  extend(output, obj2)
  output

wrap = (fn) ->
  (args...) -> fn()(args...)
  
match_values = (value1, value2) ->
  value1 == value2 or
    throw new Error("RuntimeError: Values do not match: #{value1} != #{value2}") 
  
exports.merge = merge
exports.extend = extend
exports.wrap = wrap
exports.match_values = match_values
