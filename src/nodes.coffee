lib = require './lib'
types = require './types'
_ = require('./underscore_extensions')
{error, debug} = lib

symbol_to_string_table =
  "=": "equal"
  "+": "plus"
  "-": "minus"
  "^": "circumflex"
  "~": "tilde" 
  "<": "less"
  ">": "more"
  "!": "exclamation",
  ":": "colon"
  "*": "mul"
  "/": "div"
  "%": "percent"
  "&": "ampersand"
  "|": "pipe"
 
valid_varname = (s) ->
  table = symbol_to_string_table
  ((if table[c] then "__#{table[c]}" else c) for c in s).join("")
   
exports.FunctionCallFromID = (name, args, options = {}) ->
  name2 = if options.unary then "#{name}_unary" else name
  args2 = (new FunctionArgument("", arg) for arg in args)
  new FunctionCall(new Symbol(name2), args2)

exports.node = (class_name, args...) ->
  klass = exports[class_name] or
    error("InternalError", "Cannot find node '#{class_name}'")
  new klass(args...)
  
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
    "var #{valid_varname(@name)} = #{@compile_value(env)};"
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
  constructor: (symbol_binding) ->
    {@args, @block} = symbol_binding
  process: (env) -> 
    type = @block.process(env).type
    {env: env.add_binding(@name, type), type}
  compile: (env) ->
    name = "_" + valid_varname(@name)
    type = @block.process(env).type
    value = @compile_value(env)
    "var #{name} = api.wrap(function() { return #{value}; });"

class TraitImplementationSymbolBinding extends TraitInterfaceSymbolBinding
  constructor: (symbol_binding) ->
    {@args, @block} = symbol_binding
  process: (env) -> 
    type = @block.process(env).type # check type
    {env, type}
  compile: (env) ->
    name = "_" + valid_varname(@name)
    type = @block.process(env).type
    value = @compile_value(env)
    "var #{name} = api.wrap(function() { return #{value}; });"

## Functions

class FunctionBinding
  constructor: (name, @args, @result_type, @block, options = {}) ->
    @name = if options.unary then "#{name}_unary" else name
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
    env.add_function_binding(@name, @args, result_type, env.get_context("restrictions") or [])
  compile: (env) -> 
    "var #{valid_varname(@name)} = #{@compile_value(env)};"
  compile_value: (env) ->
    block_env = @get_block_env(env)
    js_args = _(@args).pluck("name").join(', ')
    if lib.getClass(@block) == Block
      """
        function(#{js_args}) {>>
          #{@block.compile(block_env, return: true)}<<
        }
      """
    else
      "function(#{js_args}) { return #{@block.compile(block_env)}; }"

class TraitInterfaceFunctionBinding extends FunctionBinding
  compile: (env) -> 
    "var _#{valid_varname(@name)} = #{@compile_value(env)};"

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
    type = new types.Function(args, result, 
      env.get_context("trait"), env.get_context("restrictions") or [])
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
  
class Symbol
  constructor: (@name) ->
  process: (env) -> {env, type: env.get_binding(@name)}
  compile: (env) ->
    type = env.get_binding(@name)
    if (trait = env.get_context("trait")) and _(env.traits[trait].bindings).include(@name)
      "#{valid_varname(@name)}[type]"
    else
      valid_varname(@name)

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
    check_repeated_arguments()
    check_arguments_size(function_type)
    type = @match_types(env, function_type)
    {env, type: type.result}
  compile: (env) ->
    function_type = @fexpr.process(env).type
    type = @match_types(env, function_type)
    key_to_index = _.mash([k, i] for [k, v], i in type.args.args)
    sorted_args = _.sortBy(@args, (arg) -> parseInt(key_to_index[arg.name]))
    fname = valid_varname(@fexpr.compile(env))
    complete_fname = if type.trait and not env.get_context("trait_interface")
      [type_for_trait, trait] =
        _.first([t, trait] for [t, trait] in type.restrictions when trait == type.trait) or
        error("InternalError", "Cannot find type for trait '#{trait}'")
      #if type_for_trait.variable
      #  error("TypeError", "Restriction '#{type_for_trait}@#{trait}' fails"
      if env.get_context("trait_interface")
        "#{fname}[type]"
      else
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
    binding_type = if _(@args).isEmpty()
      env.add_binding(@name, new type(type_args)) 
    else
      env.add_function_binding(@name, @args, new type(type_args), env.get_context("restrictions") or []).env

##

class Comment
  constructor: (@text) ->
  process: (env) -> {env}
  compile: (env) -> "// #{@text}"

##

class TraitInterface
  constructor: (@name, @typevar, @symbol_type_definitions) ->
  process: (env) ->
    trait_env = env.in_context
      trait: @name
      trait_interface: true
      typevar: @typevar.process(env).type
      restrictions: [[@typevar.process(env).type, @name]]
    {env: env2, bindings} = TraitInterfaceSymbolType.bindings(trait_env, @symbol_type_definitions)
    new_env = env2.add_trait(@name, @typevar.name, bindings).in_context({})
    {env: new_env}
  compile: (env) -> 
    trait_env = env.in_context
      trait: @name
      trait_interface: true
      typevar: @typevar.process(env).type
      restrictions: [[@typevar.process(env).type, @name]]
    sets = (def for def in @symbol_type_definitions when lib.getClass(def) != TraitInterfaceSymbolType)      
    ("var #{valid_varname(def.name)} = {};" for def in @symbol_type_definitions).join("\n") + "\n" +
      "// traitinterface #{@name}\n" + 
      "var #{@name} = function(type) {>>\n" +
        (def.compile(trait_env) \
         for def in @symbol_type_definitions when lib.getClass(def) != TraitInterfaceSymbolType).join("\n") + "\n" +
      "return {#{("#{def.name}: _#{def.name}" for def in sets).join(', ')}};<<\n" +
      "};"
      

class TraitInterfaceSymbolType
  constructor: (@name, @type) ->
  process: (env) ->
    type = @type.process(env).type
    new_env = env.add_binding(@name, type)
    {env: new_env, type: type}
  compile: (env) ->
    "// #{@name}: #{@type.process(env).type.toShortString()}"    
  @bindings: (env, symbol_type_definitions) ->
    _.freduce symbol_type_definitions, {env, bindings: []}, (obj, def) ->
      type = def.process(obj.env).type
      typevar = obj.env.get_context("typevar")
      if not _.any(type.get_all_types(), (t) -> t.name == typevar.name)
        error("TypeError", "Function '#{def.name}' for trait '#{obj.env.get_context('trait')}' " +
          "does not mention type variable '#{typevar}'")
      {env: obj.env.add_binding(def.name, type), bindings: _(obj.bindings).concat([def.name])}


class TraitImplementation
  constructor: (@trait_name, @type, @bindings) ->
  process: (env) ->
    trait_env = env.in_context(trait: @trait_name, type: @type.process(env).type)
    bindings = (node.process(trait_env).type for node in @bindings)
    {env}
  compile: (env) -> 
    type = @type.process(env).type
    trait_env = env.in_context(trait: @trait_name, type: type)
    skip = _.mash([b.name, true] for b in @bindings)
    "// trait #{@trait_name} of #{type.name} \n" + 
      "var #{@trait_name}_#{type.name} = function() {>>\n" +  
        ("#{b.compile(trait_env)}" for b in @bindings).join("\n") + "\n" +
        "return {#{("#{b.name}: _#{b.name}" for b in @bindings).join(', ')}};" + "<<\n" +
      "};\n" +
      "var _#{@trait_name}_#{type.name} = api.merge(#{@trait_name}(#{JSON.stringify(type.name)}), #{@trait_name}_#{type.name}());" + "\n" +
      ("#{b}.#{type.name} = _#{@trait_name}_#{type.name}.#{b};" \
        for b in env.traits[@trait_name].bindings).join("\n") + "\n"

##

exports.transformTo = (classname, instance) ->
  instance.__proto__ = exports[classname].prototype
  instance  

lib.exportClasses(exports, [
  Root
  SymbolBinding, FunctionBinding, 
  TypedArgument, Type, TypeVariable, 
  TupleType, FunctionType
  Expression, ParenExpression, Block, StatementExpression
  Symbol, 
  FunctionCall, FunctionArgument
  Int, Float, String, Tuple
  TypeDefinition, TypeConstructorDefinition
  Comment
  TraitInterface, TraitInterfaceSymbolBinding, TraitImplementationSymbolBinding,
  TraitInterfaceFunctionBinding, TraitImplementationStatementBinding
  TraitInterfaceSymbolType, 
  TraitImplementation
])
