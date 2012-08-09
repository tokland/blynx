#!/usr/bin/coffee
exports.merge = (obj, obj2) ->
  output = {}
  output[k] = v for k, v of obj
  output[k] = v for k, v of obj2
  output

exports.extend = (obj, obj2) ->
  obj[k] = v for k, v of obj2
