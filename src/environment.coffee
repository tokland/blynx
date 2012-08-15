types = require 'types'
{debug, error, indent} = require 'lib'
_ = require 'underscore_extensions'

class Environment
  constructor: (fields = {}) ->
    {@bindings, @types, @traits, @context} =
      _(fields).defaults(bindings: {}, types: {}, traits: {}, context: {})
  clone: (fields = {}) ->
    all_fields = _(fields).defaults({@types, @bindings, @traits, @context})
    new Environment(all_fields) 
  inspect: ->
    print_name = (name) -> if name.match(/[a-z_]/i) then name else "(#{name})"
    types0 = (indent(4, "#{name}: #{type.traits.join(', ')}") for name, type of @types)
    traits = (indent(4, "#{name}: #{trait.methods.join(', ')} (implemented: #{trait.implemented_methods.join(', ')}}") for name, trait of @traits)
    bindings = (indent(4, "#{print_name(k)}: #{v}") for k, v of @bindings)
    
    [
      "---"
      "Environment:" 
      "  Types: " + (if _(@types).isEmpty() then "none" else "\n" + types0.join("\n")) 
      "  Traits: " + (if _(@traits).isEmpty() then "none" else "\n" + traits.join("\n"))
      "  Bindings: " + (if _(@bindings).isEmpty() then "none" else "\n" + bindings.join("\n"))
      "---"
    ].join("\n")
  add_binding: (name, type, options = {}) ->
    if @bindings[name]
      msg = options.error_msg or 
        "symbol '#{name}' already bound to type '#{@bindings[name]}'"  
      error("BindingError", msg)
    new_bindings = _.merge(@bindings, _.mash([[name, type]]))
    @clone(bindings: new_bindings)
  get_binding: (name) ->
    @bindings[name] or
      error("NameError", "undefined symbol '#{name}'")
  get_types_from_nodes: (nodes) ->
    (node.process(this).type for node in nodes)
  add_type: (name, klass, traits) ->
    @types[name] and
      error("TypeError", "type '#{name}' already defined")
    type = {klass: klass, traits: traits}
    new_types = _.merge(@types, _.mash([[name, type]]))
    @clone(types: new_types)
  get_type: (name) ->
    type = @types[name] or
      error("TypeError", "undefined type '#{name}'")
    type.klass
  add_function_binding: (name, args, result_type) ->
    restrictions = @get_context("restrictions") or []
    args_ns = ([arg.name, arg.process(this).type] for arg in args)
    args_type = new types.NamedTuple(args_ns)
    trait = @get_context("trait")
    function_type = new types.Function(args_type, result_type, trait, restrictions)
    if not @get_context("trait_interface") and trait
      namespace = types.match_types(@bindings[name], function_type)
      tv = @traits[trait].typevar
      type = @get_context("type")
      if not namespace or not types.match_types(namespace[tv], type)  
        error("TypeError", "Cannot match type of function '#{name}' for trait " +
          "'#{trait}' #{@bindings[name].toShortString()} with " +
          "the definition #{function_type.toShortString()}")
      {env: this, type: function_type}
    else
      {env: @add_binding(name, function_type), type: function_type} 
  add_trait: (name, typevar, methods, implemented_methods) ->
    if name of @traits
      error("TypeError", "Trait '#{name}' already defined")
    trait = {typevar, methods, implemented_methods}
    new_trait_methods = _.mash([[name, trait]])
    @clone(traits: _.merge(@traits, new_trait_methods))
  get_context: (name) ->
    if @context then @context[name] else null
  in_context: (new_context) ->
    @clone(context: new_context)
  is_trait_symbol: (name) ->
    trait = @get_context("trait")
    trait and _(@traits[trait].methods).include(name)
  is_inside_trait: ->
    !!@get_context("trait")
  in_trait_interface: (name, typevar) ->
    restrictions = [[typevar, name]]
    trait_env = @in_context
      trait: name
      trait_interface: true
      restrictions: restrictions
  function_type_in_context_trait: (ftype) ->
    new types.Function(ftype.args, ftype.result, 
      @get_context("trait"), @get_context("restrictions"))
  get_trait: (name) -> 
    @traits[name]

exports.Environment = Environment
