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
  
exports.merge = merge
exports.extend = extend
exports.wrap = wrap
