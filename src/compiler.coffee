vm = require 'vm'
_ = require('./underscore_extensions')
types = require './types'
lexer = require('./lexer')
nodes = require('./nodes')
grammar = require('./grammar')
lib = require './lib'
{debug, error, indent} = lib

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
    traits = (indent(4, "#{name}: #{trait.bindings.join(', ')}") for name, trait of @traits)
    bindings = (indent(4, "#{print_name(k)}: #{v}") for k, v of @bindings)
    
    [
      "---"
      "Environment:" 
      "  Types: " + (if _(@types).isEmpty() then "none" else "\n" + types0.join("\n")) 
      "  Traits: " + (if _(@traits).isEmpty() then "none" else "\n" + traits.join("\n"))
      "  Bindings: " + (if _(@bindings).isEmpty() then "none" else "\n"+bindings.join("\n"))
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
  add_trait: (name, typevar, bindings) ->
    if name of @traits
      error("TypeError", "Trait '#{name}' already defined")
    trait = {typevar, bindings}
    new_trait_bindings = _.mash([[name, trait]])
    @clone(traits: _.merge(@traits, new_trait_bindings))
  get_context: (name) ->
    if @context then @context[name] else null
  in_context: (new_context) ->
    @clone(context: new_context)
  is_trait_symbol: (name) ->
    trait = @get_context("trait")
    trait and _(@traits[trait].bindings).include(name)
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
    
##

getParser = (options) ->
  _(grammar.parser).merge
    yy: nodes
    lexer:
      lex: ->
        [name, @yytext, @yylineno] = 
          if @tokens.length > @pos then @tokens[@pos++] else ['EOF', "", ""]
        name
      setInput: (tokens) ->
        @tokens = tokens
        @pos = 0
    parseError: (msg, hash) ->
      msg = "Unexpected token '#{hash.token}' on line #{hash.line}" + 
        (if hash.expected then " (expecting: #{hash.expected})" else "")
      error("ParserError", msg)

exports.getAST = getAST = (source, options = {}) ->
  parser = getParser(debug: options.verbose)
  tokens = lexer.tokenize(source)
  parser.parse(tokens)

exports.compile = compile = (source, options = {}) ->
  env = _(["Int", "Float", "String"]).freduce new Environment, (e, name) ->
    e.add_type(name, types[name], [])
  {env: final_env, output} = getAST(source, options).compile_with_process(env)
  process.stderr.write(final_env.inspect()+"\n") if options.debug
  complete_output = "api = require('api');\n\n" + output + "\n" 
  {env: final_env, output: complete_output}
  
exports.run_js = run_js = (jscode, base_context = null) ->  
  sandbox = {console: console, require: require}
  context = base_context or vm.createContext(sandbox)
  value = vm.runInContext(jscode, context)
  {context, value}
  
exports.pretty_ast = pretty_ast = (node) ->
  name = lib.getClass(node).name 
  values = for k, v of node
    value = switch v.constructor.name
      when "Function" then null
      when "Array" then (pretty_ast(x) for x in v) 
      when "String" then v
      else pretty_ast(v)
    if value then [k, value] else null
  [name, _.compact(values)]

exports.run = (source, options = {}) ->
  output = compile(source, options).output
  run_js(output)
