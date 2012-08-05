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
    types = (indent(4, "#{name}: #{type.traits.join(', ')}") for name, type of @types)
    traits = (indent(4, "#{name}: #{_.keys(trait.bindings).join(', ')}") for name, trait of @traits)
    bindings = (indent(4, "#{print_name(k)}: #{v}") for k, v of @bindings)
    
    [
      "---"
      "Environment:" 
      "  Types: " + (if _(@types).isEmpty() then "none" else "\n" + types.join("\n")) 
      "  Traits: " + (if _(@traits).isEmpty() then "none" else "\n" + traits.join("\n"))
      "  Bindings: " + (if _(@bindings).isEmpty() then "none" else "\n"+bindings.join("\n"))
      "---"
    ].join("\n")
  add_binding: (name, type, traits = [], options = {}) ->
    if @bindings[name]
      msg = options.error_msg or "symbol '#{name}' already bound to type '#{@bindings[name]}'"  
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
  add_function_binding: (name, args, result_type, traits) ->
    args_ns = ([arg.name, arg.process(this).type] for arg in args)
    args_type = new types.NamedTuple(args_ns)
    function_type = new types.Function(args_type, result_type, null, [])
    if (trait = @get_context("trait"))
      namespace = types.match_types(@bindings[name], function_type)
      tv = @traits[trait].typevar
      type = @get_context("type")
      if not namespace or not types.match_types(namespace[tv], type)  
        error("TypeError", "Cannot match type of function '#{name}' for trait " +
          "'#{trait}' #{@bindings[name].toShortString()} with the definition #{function_type}")
    else
      @add_binding(name, function_type, traits)
  add_trait: (name, typevar, bindings) ->
    if name of @traits
      error("TypeError", "Trait '#{name}' already defined")
    trait = {typevar, bindings}
    new_trait_bindings = _.mash([[name, trait]])
    new_env = _(_.pairs(bindings)).freduce this, (env, [name, binding]) ->
      env.add_binding(name, binding)
    new_env.clone(traits: _.merge(@traits, new_trait_bindings))
  get_context: (name) ->
    if @context then @context[name] else null
  in_context: (new_context) ->
    @clone(context: new_context)
    
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
  {env: final_env, output: output + "\n"}
  
exports.run_js = run_js = (jscode, base_context = null) ->  
  sandbox = {api: require('./api'), console: console}
  context = base_context or vm.createContext(sandbox)
  value = vm.runInContext(jscode, context)
  {context, value}

exports.run = (source, options = {}) ->
  output = compile(source, options).output
  run_js(output)
