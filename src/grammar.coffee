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
    o 'ID ( ArgumentDefinitionList ) : Type = BlockOrExpression', -> new Function($1, $3, $6, $8)
  ]

  ArgumentDefinitionList: 
    r("ArgumentDefinition", join: ',', min: 0)

  BlockOrExpression: [
    o "Block"
    o "Expression"
  ]
 
  ArgumentDefinition: [
    o "ID : Type", -> new ArgumentDefinition($1, $3)
  ]

  Expression: [
    o 'InnerExpression', -> new Expression($1)
  ]
  
  InnerExpression: [
    o 'Literal'
    o 'Symbol'
  ]

  Literal: [
    o 'INTEGER', -> new Int($1)
    o 'FLOAT', -> new Float($1)
    o 'STRING', -> new String($1)
  ]

  Symbol: [
    o 'ID', -> new Symbol($1)
  ]

  Type: [
    o "ID_CAP", -> new Type($1, [])
  ]

operators = [
]

exports.parser = new jison.Parser
  bnf: grammar
  operators: operators
  startSymbol: 'Root'
