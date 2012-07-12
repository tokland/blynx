#!/usr/bin/coffee
_ = require './underscore_extensions'
{error, debug} = require './lib'

exports.tc = (name) ->
  class Obj
    name: name
    constructor: ->
      @args = arguments
      
exports.getAt = (array, index) ->
  value = array[index]
  if value == undefined
    error("ValueError", "getAt with index #{index} out of bounds")
  else
    value

exports.getOpenSlice = getOpenSlice = (array, from, to) ->
  unless from >= 0 && from <= array.length && to >= 0 && to <= array.length
    error("ValueError", "API: getSlice with indexes out of bounds")
  array.slice(from, to)

exports.getSlice = (array, from, to) ->
  getOpenSlice(array, from, to+1)
  
exports.update = _.update

exports.openRange = (start, end) -> _.range(start, end)

exports.range = (start, end) -> _.range(start, end+1)
