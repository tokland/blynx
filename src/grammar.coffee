jison = require 'jison'
{createGrammarItem: o, recursiveGrammarItem: r} = require './lib'

grammar =
  Root: [
    ['EOF', 'return new yy.Root([]);']
    ['Lines EOF', 'return new yy.Root($1);']
  ]

  Lines: 
    r 'Line', name: 'Lines', min: 1

  Line: [
    o 'COMMENT TERMINATOR', -> new Comment($1)
    o 'Statement TERMINATOR'
    o 'Expression TERMINATOR', -> new StatementExpression($1)
    o 'TERMINATOR'
  ]

  Block: [
    o 'INDENT Lines DEDENT', -> new Block($2)
  ]
    
  Statement: [
    o 'TypeDefinition'
    o 'SymbolBinding'
    o 'FunctionBinding'
  ]
  
  TypeDefinition: [
    o 'TYPE CAPID = TypeConstructorList', -> new TypeDefinition($2, [], $4)
    o 'TYPE CAPID ( TypeArguments ) = TypeConstructorList', -> new TypeDefinition($2, $4, $7)
  ]
  
  TypeArguments:
    r 'TypeVariable', name: "TypeArguments", min: 1, join: ','
  
  TypeVariable: [
    o 'ID', -> new TypeVariable($1)
  ]

  TypeConstructorList:
    r 'TypeConstructor', min: 1, join: '|'

  TypeConstructor: [
    o 'CAPID', -> new TypeConstructorDefinition($1, [])
    o 'CAPID ( TypedArgumentList )', -> new TypeConstructorDefinition($1, $3)
  ]
  
  SymbolBinding: [
    o 'ID = BlockOrExpression', -> new SymbolBinding($1, $3)
    o '( OpSymbol ) = BlockOrExpression', -> new SymbolBinding($2, $5)
  ]
  
  FunctionBinding: [
    o 'ID ( ) : Type = BlockOrExpression', 
      -> new FunctionBinding($1, [], $5, $7)
    o 'ID ( TypedArgumentList ) : Type = BlockOrExpression', 
      -> new FunctionBinding($1, $3, $6, $8)
    o '( OpSymbol ) ( TypedArgumentList ) : Type = BlockOrExpression', 
      -> new FunctionBinding($2, $5, $8, $10)
    o '( $ OpSymbol ) ( TypedArgumentList ) : Type = BlockOrExpression', 
      -> new FunctionBinding($3, $6, $9, $11, unary: true)
  ]
  
  OpSymbol: (
    o(symbol) for symbol in [
      'SYMBOL_EQUAL', 'SYMBOL_PLUS', 'SYMBOL_MINUS', 'SYMBOL_CIRCUMFLEX'
      'SYMBOL_TILDE', 'SYMBOL_LESS', 'SYMBOL_MORE', 'SYMBOL_EXCLAMATION'
      'SYMBOL_COLON', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT'
      'SYMBOL_AMPERSAND', 'SYMBOL_PIPE', '&', '|', '!'
    ]
  )

  TypedArgumentList: 
    r 'TypedArgument', join: ',', min: 1

  BlockOrExpression: [
    o 'Block'
    o 'Expression'
  ]
 
  TypedArgument: [
    o 'ID : Type', -> new TypedArgument($1, $3)
  ]

  Expression: [
    o 'InnerExpression', -> new Expression($1)
  ]
  
  InnerExpression: [
    o '( Expression )', -> new ParenExpression($2)
    o 'Symbol'
    o 'FunctionCall'
    o 'Literal'
    o 'UnaryOp'
    o 'BinaryOp'
  ]
  
  Symbol: [
    o 'ID', -> new Symbol($1)
    o 'CAPID', -> new Symbol($1)
    o '( OpSymbol )', -> new Symbol($2)
  ]
  
  UnaryOp:
    o("#{sym} Expression", (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY') \
      for sym in ['SYMBOL_MINUS', 'SYMBOL_PLUS', 'SYMBOL_EXCLAMATION', '!', 'SYMBOL_TILDE']
  
  BinaryOp:
    o("Expression #{sym} Expression", -> new FunctionCallFromID($2, [$1, $3])) for sym in [
      'SYMBOL_EQUAL', 'SYMBOL_PLUS', 'SYMBOL_MINUS', 'SYMBOL_CIRCUMFLEX',
      'SYMBOL_TILDE', 'SYMBOL_LESS', 'SYMBOL_MORE', 'SYMBOL_EXCLAMATION',
      '!', 'SYMBOL_COLON', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT',
      'SYMBOL_AMPERSAND', '&', 'SYMBOL_PIPE', '|'
    ]
  
  Literal: [
    o 'INTEGER', -> new Int($1)
    o 'FLOAT', -> new Float($1)
    o 'STRING', -> new String($1)
    o 'Tuple', -> new Tuple($1)
  ]

  Tuple: [
    o '( Expression , TupleList )', -> [$2].concat($4)
  ]

  TupleList: 
    r 'Expression', name: 'TupleList', join: ',', min: 1

  Type: [
    o 'CAPID', -> new Type($1, [])
    o 'CAPID ( TypeList )', -> new Type($1, $3)
    o '( TupleTypeList )', -> new TupleType($2)
    o 'TypeVariable'
  ]
  
  TypeList:
    r 'Type', name: 'TypeList', min: 1, join: ','
  
  TupleTypeList: 
    r 'Type', name: 'TupleTypeList', min: 2, join: ','

  FunctionCall: [
    o 'ID ( )', -> new FunctionCall(new Symbol($1), [])
    o 'ID ( FunctionArgumentList )', -> new FunctionCall(new Symbol($1), $3)
    o 'CAPID ( FunctionArgumentList )', -> new FunctionCall(new Symbol($1), $3)
  ]  

  FunctionArgumentList:
    r 'FunctionArgument', join: ',', min: 1
    
  FunctionArgument: [
    o 'ID = Expression', -> new FunctionArgument($1, $3)
    o 'Expression', -> new FunctionArgument('', $1)
  ]
  
operators = [
  ['nonassoc',  'INDENT', 'DEDENT']
  ['left', 'SYMBOL_AMPERSAND', '&', 'SYMBOL_PIPE', '|']
  ['right', 'UNARY']
  ['left', 'SYMBOL_LESS', 'SYMBOL_MORE']
  ['left', 'SYMBOL_CIRCUMFLEX', 'SYMBOL_TILDE']
  ['left', 'SYMBOL_EQUAL', 'SYMBOL_EXCLAMATION', '!']
  ['right', 'SYMBOL_COLON']
  ['left', 'SYMBOL_PLUS', 'SYMBOL_MINUS']
  ['left', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT']
]

exports.parser = new jison.Parser
  bnf: grammar
  operators: operators
  startSymbol: 'Root'
