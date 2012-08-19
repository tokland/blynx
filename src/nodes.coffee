eco = require 'eco'
lib = require 'lib'
types = require 'types'
_ = require 'underscore_extensions'
{error, debug} = lib

render = (template, namespace) ->
  eco.render template, _(namespace).merge
    escape: (s) -> s
    json: JSON.stringify
    jsname: jsname
  
jsname = (s) ->
  table = lib.symbol_to_string_table
  ((if table[c] then "__#{table[c]}" else c) for c in s).join("")

native_binary_operators = "+ - * / % < <= == > >= || &&".split(" ")
native_unary_operators = "+ - !".split(" ")
   
##
  
class Root
  constructor: (@nodes) ->
  compile_with_process: (env) ->
    output = for node in @nodes when node
      {env, type} = node.process(env)
      node.compile(env)
    {env, output: lib.indent_code(_(output).compact().join("\n"))}
    
## Statements

class SymbolBinding
  constructor: (@name, @block) ->
  process: (env) -> 
    type = @block.process(env).type
    {env: env.add_binding(@name, type), type}
  compile: (env) ->
    "var #{jsname(@name)} = #{@compile_value(env)};"
  compile_value: (env) ->
    if lib.getClass(@block) == Expression
      @block.compile(env)
    else
      """
        (function() {>>
          #{@block.compile(env, return: true)}<<
        }).call(this)
      """

class TraitInterfaceSymbolBinding extends SymbolBinding
  process: (env) -> 
    type = @block.process(env).type
    {env: env.add_binding(@name, type), type}
  compile: (env) ->
    name = "_" + jsname(@name)
    type = @block.process(env).type
    value = @compile_value(env)
    "var #{name} = api.wrap(function() { return #{value}; });"

class TraitImplementationSymbolBinding extends TraitInterfaceSymbolBinding
  process: (env) -> 
    type = @block.process(env).type # TODO: check type
    {env, type}
    
## Functions

class FunctionBinding
  constructor: (name, @args, @result_type, @block, options = {}) ->
    @name = if options.unary then "#{name}_unary" else name
    @restrictions = options.restrictions or []
  get_block_env: (env) ->
    _.freduce @args, env, (block_env, arg) ->
      block_env.add_binding(arg.name, arg.process(env).type, 
        error_msg: "argument '#{arg.name}' already defined in function binding")
  process: (env) ->
    block_env = @get_block_env(env)
    block_type = @block.process(block_env).type
    result_type = @result_type.process(env).type
    unless namespace = types.match_types(block_type, result_type)
      msg = "function '#{@name}' should return '#{result_type}' but returns '#{block_type}'"
      error("TypeError", msg)
    restrictions = (r.get(env) for r in @restrictions)
    env.add_function_binding(@name, @args, result_type, restrictions: restrictions)
  compile: (env) -> 
    "var #{jsname(@name)} = #{@compile_value(env)};"
  compile_value: (env) ->
    block_env = @get_block_env(env)
    js_args = (arg.name for arg in @args).join(', ')
    if lib.getClass(@block) == Block
      """
        function(#{js_args}) {>>
          #{@block.compile(block_env, return: true)}<<
        }
      """
    else
      "function(#{js_args}) { return #{@block.compile(block_env)}; }"

class Restriction
  constructor: (@typevar, @trait) -> 
  get: (env) ->
    env.get_trait(@trait)
    [@typevar.process(env).type, @trait]
  
class TraitInterfaceFunctionBinding extends FunctionBinding
  compile: (env) -> 
    "var _#{jsname(@name)} = #{@compile_value(env)};"

class TraitImplementationStatementBinding extends TraitInterfaceFunctionBinding

class TypedArgument
  constructor: (@name, @type) ->
  process: (env) -> {env, type: @type.process(env).type}

class Type
  constructor: (@name, @args) ->
  process: (env) ->
    type_args = env.get_types_from_nodes(@args)
    type = env.get_type(@name)
    {env, type: new type(type_args)}

class TypeVariable
  constructor: (@name) ->
  process: (env) -> {env, type: new types.Variable(@name)}

class TupleType
  constructor: (@types) ->
  process: (env) ->
    tuple_args = env.get_types_from_nodes(@types)
    {env, type: new types.Tuple(tuple_args)}

class FunctionType
  constructor: (@args, @result) ->
  process: (env) ->
    args = new types.NamedTuple([arg.name, arg.process(env).type] for arg in @args)
    result = @result.process(env).type
    type = new types.Function(args, result, null, [])
    {env, type: type}

## Expressions

class Expression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> @value.compile(env)

class ParenExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "(" + @value.compile(env) + ")"

class Block
  constructor: (@nodes) ->
  process: (env, options = {}) ->
    _(@nodes).isNotEmpty() or error("SyntaxError", "Empty block")
    for node in @nodes
      {env, type} = node.process(env, options)
    {env, type}
  compile: (env, options = {}) ->
    _(options).defaults(return: false)
    compiled = for node in @nodes
      {env, type} = node.process(env, options)
      node.compile(env)
    last_expr = _.last(compiled)
    tail = if options.return then ["return #{last_expr}"] else [last_expr]
    _(compiled[0...-1]).concat(tail).join("\n")

class StatementExpression
  constructor: (@value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> "#{@value.compile(env)};"
  
class SymbolReplacement
  constructor: (@symbol) ->
  process: (env) -> 
    {env, type: env.get_binding(@symbol.name)}
  compile: (env) ->
    name = jsname(@symbol.name)
    if env.is_trait_symbol(@symbol.name) then "#{name}[type]" else name

class FunctionArgument
  constructor: (@name, @value) ->
  process: (env) -> @value.process(env)
  compile: (env) -> @value.compile(env)

class FunctionCall
  constructor: (@fexpr, @args) ->
  match_types: (env, function_type) ->
    function_args = function_type.args
    result = function_type.result
    given_args = new types.NamedTuple([a.name, a.process(env).type] for a in @args)
    merged = function_args.merge(given_args)
    namespace = types.match_types(function_args, merged) or
      error("TypeError", "function '#{function_type}', called with arguments '#{merged}'")
    function_type.join(namespace)
  process: (env) ->
    check_function_type = (function_type) =>
      unless lib.getClass(function_type) == types.Function
        error("TypeError", "binding '#{function_type}' called, but it's not a function")
    check_repeated_arguments = =>       
      keys = (arg.name for arg in @args)
      repeated_keys = (k for k, ks of _.groupBy(keys, _.identity) when k and ks.length > 1)
      if (repeated_key = _.first(repeated_keys))
        error("ArgumentError", "function call repeats argument '#{repeated_key}'")
    check_arguments_size = (function_type) =>
      size = _.size(function_type.args.get_types())
      if _.size(@args) != size
        msg = "function '#{@fexpr.compile(env)}' takes #{size} arguments but #{@args.length} given"
        error("ArgumentError", msg)
    function_type = @fexpr.process(env).type
    check_function_type(function_type)
    check_arguments_size(function_type)
    type = @match_types(env, function_type)
    env.check_restrictions(type)
    check_repeated_arguments()
    {env, type: type.result}
  compile: (env) ->
    function_type = @fexpr.process(env).type
    type = @match_types(env, function_type)
    key_to_index = _.mash([k, i] for [k, v], i in type.args.args)
    sorted_args = _.sortBy(@args, (arg) -> parseInt(key_to_index[arg.name]))
    fname = jsname(@fexpr.compile(env))
    complete_fname = if type.trait and not env.is_inside_trait()
      [type_for_trait, trait] =
        _.first([t, trait] for [t, trait] in type.restrictions when trait == type.trait) or
        error("InternalError", "Cannot find type for trait '#{trait}'")
      if type_for_trait.variable
        error("TypeError", "Restriction '#{type_for_trait}@#{trait}' fails")
      "#{fname}.#{type_for_trait}"
    else
      fname
    complete_fname + "(" + (arg.compile(env) for arg in sorted_args).join(', ') + ")"

## Literals
  
class Int
  constructor: (@value_token) ->
  process: (env) -> {env, type: new(env.get_type("Int"))}
  compile: (env) -> @value_token

class Float
  constructor: (@value_token) ->
  process: (env) -> {env, type: new(env.get_type("Float"))}
  compile: (env) -> @value_token

class String
  constructor: (string_token) -> @value = eval(string_token)
  process: (env) -> {env, type: new(env.get_type("String"))}
  compile: (env) -> JSON.stringify(@value)

class Tuple
  constructor: (@values) ->
  process: (env) ->
    args = env.get_types_from_nodes(@values)
    {env, type: new types.Tuple(args)}
  compile: (env) ->
    "[" + _(@values).invoke("compile", env).join(", ") + "]" 

##

class TypeDefinition
  constructor: (@name, @args, @traits, @constructors) ->
  process: (env) ->
    args = env.get_types_from_nodes(@args)
    type = types.buildType(@name, @args.length)
    env_with_type = env.add_type(@name, type, @traits)
    new_env = _.freduce @constructors, env_with_type, (e, constructor) ->
      constructor.add_binding(e, type, args)
    {env: new_env}
  compile: (env) ->
    "// type #{@name}\n" +
      _(@constructors).invoke("compile", env).join("\n") + "\n"

class TypeConstructorDefinition
  constructor: (@name, @args) ->
  compile: (env) ->
    if _(@args).isEmpty()
      "var #{@name} = {};"
    else
      names = _(@args).pluck("name")
      val = "{" + ("#{JSON.stringify(n)}: #{n}" for n in names) + "}"
      "var #{@name} = function(#{names.join(', ')}) { return #{val}; };"
  add_binding: (env, type, type_args) ->
    type = new type(type_args)
    binding_type = if _(@args).isEmpty()
      env.add_binding(@name, type) 
    else
      env.add_function_binding(@name, @args, type).env

##

class Comment
  constructor: (@text) ->
  process: (env) -> {env}
  compile: (env) -> "// #{@text}"

##

class TraitInterface
  constructor: (@name, @typevar, @trait_interface_statements) ->
  process: (env) ->
    typevar = @typevar.process(env).type
    tenv = env.in_trait_interface(@name, typevar) 
    nodes = @trait_interface_statements
    {env: env2, methods, imethods} = _.freduce nodes, {env: tenv, methods: [], imethods: []}, (obj, node) =>
      type = node.process(obj.env).type
      if not _.any(type.get_all_types(), (t) -> t.name == typevar.name)
        error("TypeError", "Function '#{node.name}' for trait '#{@name}' " +
              "does not mention type variable '#{typevar}'")
      new_env = obj.env.add_binding(node.name, type)
      new_methods = _(obj.methods).concat([node.name])
      new_imethods = if lib.getClass(node) == TraitInterfaceSymbolType then obj.imethods \ 
        else _(obj.imethods).concat([node.name])
      {env: new_env, methods: new_methods, imethods: new_imethods}
    new_env = env2.add_trait(@name, @typevar.name, methods, imethods).in_context({})
    {env: new_env}
  compile: (env) -> 
    typevar = @typevar.process(env).type
    tenv = env.in_trait_interface(@name, typevar) 
    nodes = (node for node in @trait_interface_statements \
              when lib.getClass(node) != TraitInterfaceSymbolType)
    render """
      /* traitinterface <%= @trait_name %> */
      <% for node in @trait_interface_statements: %>
        var <%= @jsname(node.name) %> = {}; 
      <% end %>
      var <%= @trait_name %> = function(type) {>>
        <% for node in @nodes: %>
          <%= node.compile(@env) %>
        <% end %>
        return {<%= (node.name + " : _" + node.name for node in @nodes).join(', ') %>};<<
      }
    """,
      env: tenv
      trait_name: @name
      jsname: jsname
      trait_interface_statements: @trait_interface_statements
      nodes: nodes
      
class TraitImplementation
  constructor: (@trait_name, @type, @nodes) ->
  process: (env) ->
    implemented_symbols = (node.name for node in @nodes)
    trait = env.get_trait(@trait_name)
    all_implemented_methods = _(trait.implemented_methods).union(implemented_symbols)
    missing_methods = _(trait.methods).difference(all_implemented_methods)
    if not _.isEmpty(missing_methods)
      error("TypeError", "type '#{@type.name}' lacks implementations: #{missing_methods.join(', ')}")
    new_env = env.add_trait_for_type(@type.name, @trait_name)
    tenv = new_env.in_context(trait: @trait_name, type: @type.process(env).type)
    for node in @nodes
      node.process(tenv).type
    {env: new_env}
  compile: (env) -> 
    type = @type.process(env).type
    tenv = env.in_context(trait: @trait_name, type: type)
    render """
      /* trait <%= @trait %> of <%= @type %> */
       
      var <%= @trait %>_<%= @type %> = function() {>>
        var type = <%= @json(@type) %>;
        <% for b in @nodes: %>  
          <%= b.compile(@env) %>
        <% end %>
        return {<%= (@jsname(node.name) + ' : _' + @jsname(node.name) for node in @nodes).join(', ') %>};<<
      }
      
      var _<%= @trait %>_<%= @type %> = api.merge(<%= @trait %>(<%= @json(@type) %>), <%= @trait %>_<%= @type %>());
      <% for bname in @env.traits[@trait].methods: %>
        <%= @jsname(bname) %>.<%= @type %> = _<%= @trait %>_<%= @type %>.<%= @jsname(bname) %>; 
      <% end %>
    """,
      env: tenv
      nodes: @nodes
      trait: @trait_name
      type: type.name

class TraitInterfaceSymbolType
  constructor: (@symbol, @type) -> @name = @symbol.name
  process: (env) ->
    type0 = @type.process(env).type
    type = env.function_type_in_context_trait(type0)
    new_env = env.add_binding(@name, type)
    {env: new_env, type: type}
  compile: (env) ->
    "// #{@name}: #{@type.process(env).type.toShortString()}"    

##

class Symbol
  constructor: (name, options = {}) -> 
    @unary = !!options.unary
    @name = if @unary then "#{name}_unary" else name
  process: (env) -> {env, type: env.get_binding(@name)}
  compile: (env) -> @name

class Id
  constructor: (@name) ->
  compile: (env) -> @name 

class StringQ
  constructor: (name) -> @name = name[1...-1]
  compile: (env) -> @name 

class External
  constructor: (@external_name, @symbol, @type) ->
  process: (env) ->
    type = @type.process(env).type
    {env: env.add_binding((@symbol or @external_name).name, type), type}
  compile: (env) ->
    type = @type.process(env).type
    external_name = @external_name.compile(env)
    name = jsname(@symbol.name or external_name)
    value = if @symbol.unary and _(native_unary_operators).include(external_name)
      if lib.getClass(type) != types.Function or _.size(type.args.get_types()) != 1
        error("TypeError", "Expected unary function, got '#{type}'")
      "function(x) { return #{external_name}x; }"
    else if _(native_binary_operators).include(external_name)
      if lib.getClass(type) != types.Function or _.size(type.args.get_types()) != 2
        error("TypeError", "Expected binary function, got '#{type}'")
      "function(x, y) { return x #{external_name} y; }"
    else
      external_name
    "/* external #{external_name} */\n" +
      (if name != external_name then "var #{name} = #{value};\n" else "") 

##

exports.FunctionCallFromID = (name, args, options = {}) ->
  args_nodes = (new FunctionArgument("", arg) for arg in args)
  new FunctionCall(new SymbolReplacement(new Symbol(name, options)), args_nodes)

exports.node = (class_name, args...) ->
  klass = exports[class_name] or
    error("InternalError", "Cannot find node '#{class_name}'")
  new klass(args...)

exports.transformTo = (classname, instance) ->
  instance.__proto__ = exports[classname].prototype
  instance  

##

lib.exportClasses(exports, [
  Root
  SymbolBinding, FunctionBinding, Restriction 
  TypedArgument, Type, TypeVariable, 
  TupleType, FunctionType
  Expression, ParenExpression, Block, StatementExpression
  Symbol, SymbolReplacement,
  FunctionCall, FunctionArgument
  Int, Float, String, Tuple
  TypeDefinition, TypeConstructorDefinition
  Comment
  TraitInterface, TraitInterfaceSymbolBinding, TraitImplementationSymbolBinding,
  TraitInterfaceFunctionBinding, TraitImplementationStatementBinding
  TraitInterfaceSymbolType, 
  TraitImplementation,
  Id, StringQ,
  External
])
