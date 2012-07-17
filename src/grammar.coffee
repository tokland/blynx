jison = require 'jison'
{createGrammarItem: o, recursiveGrammarItem: r} = require './lib'

grammar =
  Root: [
    ["EOF", "return new yy.Root([]);"]
    ["Body EOF", "return new yy.Root($1);"]
  ]

  Body: [
    o "Line", -> [$1]
    o "Body Line", -> $1.concat($2)
  ]

  Line: [
    o 'Statement TERMINATOR'
    o 'Expression TERMINATOR', -> new StatementExpression($1)
    o 'TERMINATOR'
  ]

  Block: [
    o 'INDENT Body DEDENT', -> new Block($2)
  ]
    
  Statement: [
    o 'SymbolBinding'
    o 'FunctionBinding'
  ]

  SymbolBinding: [
    o 'ID = BlockOrExpression', -> new SymbolBinding($1, $3)
  ]
  
  FunctionBinding: [
    o 'ID ( ) : Type = BlockOrExpression', -> new FunctionBinding($1, [], $5, $7)
    o 'ID ( TypedArgumentList ) : Type = BlockOrExpression', -> new FunctionBinding($1, $3, $6, $8)
  ]

  TypedArgumentList: 
    r("TypedArgument", join: ',', min: 1)

  BlockOrExpression: [
    o "Block"
    o "Expression"
  ]
 
  TypedArgument: [
    o "ID : Type", -> new TypedArgument($1, $3)
  ]

  Expression: [
    o 'InnerExpression', -> new Expression($1)
  ]
  
  InnerExpression: [
    o 'ID', -> new Symbol($1)
    o 'FunctionCall'
    o 'Literal'
    o 'Tuple', -> new Tuple $1
  ]

  Literal: [
    o 'INTEGER', -> new Int($1)
    o 'FLOAT', -> new Float($1)
    o 'STRING', -> new String($1)
  ]

  Tuple: [
    o "( )", -> []
    o "( Expression , TupleList )", -> [$2].concat($4)
  ]

  TupleList: r("Expression", join: ',', name: "TupleList")

  Type: [
    o "CAPID", -> new Type($1)
  ]

  FunctionCall: [
    o 'ID ( )', -> new FunctionCall(new Symbol($1), [])
    o 'ID ( ArgumentList )', -> new FunctionCall(new Symbol($1), $3)
  ]  

  ArgumentList: r("Expression", name: "ArgumentList", min: 1, join: ',')

operators = [
]

exports.parser = new jison.Parser
  bnf: grammar
  operators: operators
  startSymbol: 'Root'
