_ = require('underscore')
jison = require 'jison'
{debug, error, createGrammarItem: o} = require './lib'

grammar =
  Root: [
    ["EOF", "return new yy.Root([]);"]
    ["Body EOF", "return new yy.Root($1);"]
  ]

  # Body: r("Body", "Line")
  Body: [
    o "Line", -> [$1]
    o "Body Line", -> $1.concat $2
  ]

  Block: [
    o 'INDENT Body DEDENT', -> new Block $2
  ]
  
  Line: [
    o 'Expression TERMINATOR', -> new StatementExpression($1)
    o 'Statement TERMINATOR'
    o 'COMMENT TERMINATOR', -> new Comment($1)
    o 'TERMINATOR'
  ]
    
  Statement: [
    o 'TYPE ID_CAP = TypeConstructors', -> new NewType($2, [], $4)
    o 'TYPE ID_CAP ( TypeDefinitionArgs ) = TypeConstructors', -> new NewType($2, $4, $7)
    o 'Binding'
    o 'External'
    o 'IF Expression OptionalThen Block', -> new StatementIf $2, $4
    o 'RETURN Expression', -> new Return($2)
  ]

  Binding: [
    o 'ID = BlockOrExpression', -> new Binding($1, $3)
    o 'ID ( ) : Type = BlockOrExpression', -> new Function($1, [], $5, $7) 
    o 'ID ( DefArglist ) : Type = BlockOrExpression', -> new Function($1, $3, $6, $8)
    o '( InfixOperators ) ( DefArglist ) : Type = BlockOrExpression', -> new Function($2, $5, $8, $10)
  ]
 
  External: [
    o 'EXTERNAL FunctionName = Type', -> new External($2, $2, $4)
    o 'EXTERNAL FunctionName AS FunctionName = Type', -> new External($2, $4, $6)
  ]
  
  FunctionName: [
    o 'ID'
    o 'ID_CAP'
    o '( InfixOperators )', -> $2
  ]
  
  InfixOperators: [
    o '+'
    o '-'
    o 'MATH_OP'
    o 'COMPARE_OP'
    o 'BOOL_OP'
  ]
  
  # TypeConstructors: recursive("TypeConstructors", "TypeConstructor", "|")
  TypeConstructors: [
    o "TypeConstructor", -> [$1]
    o "TypeConstructors | TypeConstructor", -> $1.concat($3)
  ]

  TypeConstructor: [
    o "ID_CAP", -> new TypeConstructorDefinition($1, [])
    o "ID_CAP ( TypeDefinitionArgs )", -> new TypeConstructorDefinition($1, $3)
  ]
  
  DefArglist: [
    #o "", -> [] # Manage empty list on parent node, otherwise parser conflicts
    o "DefArg", -> [$1]
    o "DefArglist , DefArg", -> $1.concat($3)
  ]

  DefArg: [
    o "ID : Type", -> new DefArg($1, $3)
  ]
  
  Type: [
    o "ID", -> new TypeVariable($1)
    o "ID_CAP", -> new Type($1, [])
    o "ID_CAP ( TypeArgs )", -> new Type($1, $3)
    o "[ Type ]", -> new ArrType($2)
    o "{ RecordTypeList OptComma }", -> new RecordType($2)
    o "( TupleTypeList )", -> new TupleType($2)
    o "( TupleTypeList ) -> Type", -> new FunctionType($2, $5)
  ]

  RecordTypeList: [
    o "", -> []
    o "RecordType", -> [$1]
    o "RecordTypeList , RecordType", -> $1.concat($3)
  ]

  RecordType: [
    o 'ID : Type', -> {key: $1, value: $3}
  ]
  
  TypeArgs: [
    o "Type", -> [$1]
    o "TypeArgs , Type", -> $1.concat($3)
  ]
  
  TupleTypeList: [
    o "", -> []
    o "Type", -> [$1]
    o "TupleTypeList , Type", -> $1.concat($3)
  ],

  TypeDefinitionArgs: [
    o 'ID', -> [$1]
    o 'TypeDefinitionArgs , ID', -> $1.concat $3
  ]

  Expression: [
    o 'InnerExpression', -> new Expression($1)
  ]
  
  InnerExpression: [
    o 'FunctionCall'
    o 'ID_CAP', -> new TypeConstructor($1, [])
    o 'ID_CAP ( Arglist )', -> new TypeConstructor($1, $3)
    o '( Expression )', -> new ParenExpression($2)
    o 'Tuple', -> new Tuple $1
    o 'Literal'
    o 'ID', -> new Identifier $1
    o 'RecordAccess'
    o 'ArrayAccess'
    o 'Range'
    o 'Expression + Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression - Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression MATH_OP Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression COMPARE_OP Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression BOOL_OP Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'UNARY_OP Expression', -> new UnaryOp($1, $2)
    o '- Expression', -> new UnaryOp("-", $2)
    o '+ Expression', -> new UnaryOp("+", $2)
    o 'IfThenElse'
  ]

  IfThenElse: [
    o 'IF Expression THEN Expression ELSE Expression', -> new If $2, $4, $6
    o 'IF Expression OptionalThen Block ELSE Block', -> new If $2, $4, $6
  ]
    
  OptionalThen: [
    o ''
    o 'THEN'
  ]

  ArrayAccess: [
    o 'Expression [ Expression ]', -> 
      new FunctionCallFromID("getAt", [$1, $3])
    o 'Expression [ Expression .. Expression ]', -> 
      new FunctionCallFromID("getSlice", [$1, $3, $5])
    o 'Expression [ Expression ... Expression ]', ->
      new FunctionCallFromID("getOpenSlice", [$1, $3, $5]) 
  ]
  
  Range: [
    o '[ Expression .. Expression ]', -> 
      new Range($2, $4)
    o '[ Expression ... Expression ]', ->
      new OpenRange($2, $4) 
  ]

  RecordAccess: [
    o 'Expression . ID', -> new RecordAccess($1, $3)
  ]
  
  FunctionCall: [
    o 'ID ( )', -> new FunctionCallFromID($1, [])
    o 'ID ( Arglist )', -> new FunctionCallFromID($1, $3)
    o 'RecordAccess ( CommaSepExpressions )', -> new FunctionCall($1, $3)
  ]
  
  Identifier: [
    o 'ID', -> new Identifier $1
  ]
  
  CommaSepExpressions: [
    o "", -> []
    o "CommaSepExpression", -> [$1]
    o "CommaSepExpressions , CommaSepExpression", -> $1.concat($3)
  ]
  
  CommaSepExpression: [
    o "Expression"
  ]

  BlockOrExpression: [
    o "Block"
    o "Expression"
  ]

  Tuple: [
    o "( )", -> []
    o "( Expression , TupleList )", -> [$2].concat $4
  ]
  
  TupleList: [
    o "Expression", -> [$1]
    o "TupleList , Expression", -> $1.concat $3
  ],

  Literal: [
    o 'INTEGER', -> new Int $1
    o 'FLOAT', -> new Float $1
    o 'STRING', -> new String $1
    o 'Array', -> new Arr $1 
    o 'Record', -> new Record $1 
  ]

  Record: [
    o '{ RecordItems OptComma }', -> $2
  ]

  RecordItems: [
    o '', -> []
    o 'RecordItem', -> [$1]
    o 'RecordItems , RecordItem', -> $1.concat $3
  ]
  
  RecordItem: [
    o 'ID = Expression', -> {key: $1, value: $3}
  ]

  Array: [
    o '[ ]', -> []
    o '[ Arglist OptComma ]', -> $2
  ]

  Arglist: [
    #o '', -> []
    o 'Expression', -> [$1]
    o 'Arglist , Expression', -> $1.concat $3
  ]

  OptComma: [
    o ''
    o ','
  ]

operators = [
  ['nonassoc',  'INDENT', 'DEDENT']
  ["left", ".", "["]
  ["left", "BOOL_OP"]
  ["left", "COMPARE_OP"]
  ["left", "+", "-", "!"]
  ["left", "MATH_OP"]
  ["right", "IF", "THEN", "ELSE"],
  ["right", "UNARY_OP"]
]

grammar =
  bnf: grammar
  operators: operators
  startSymbol: 'Root'

getParser = (options = {}) ->
  _(options).defaults(debug: false)
  new jison.Parser(grammar, options)

exports.getParser = getParser

if not module.parent
  fs = require('fs')
  parser = getParser(debug: true)
  filename = 'parser.js'
  fs.writeFile(filename, parser.generate())
  debug("Parser script created: #{filename}")
