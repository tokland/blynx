jison = require 'jison'
{createGrammarItem: o, recursiveGrammarItem: r} = require 'lib'

grammar =
  Root: [
    ['EOF', 'return new yy.Root([]);']
    ['Lines EOF', 'return new yy.Root($1);']
  ]

  Lines: [
    o 'Line TERMINATOR', -> [$1]
    o 'Line TERMINATOR Lines', -> [$1].concat($3)
  ]

  Line: [
    o 'COMMENT', -> new Comment($1)
    o 'Statement'
    o 'Expression', -> new StatementExpression($1)
    o ''
  ]

  Block: [
    o 'INDENT Lines DEDENT', -> new Block($2)
  ]
    
  Statement: [
    o 'TypeDefinition'
    o 'TraitInterface'
    o 'TraitImplementation'
    o 'SymbolBinding'
    o 'FunctionBinding'
  ]
  
  TypeDefinition: [
    o 'TYPE CAPID TypeTraits = TypeConstructorList', 
        -> new TypeDefinition($2, [], $3, $5)
    o 'TYPE CAPID ( TypeArguments ) TypeTraits = TypeConstructorList', 
        -> new TypeDefinition($2, $4, $6, $8)
  ]

  TraitInterface: [
    o 'TRAITINTERFACE CAPID TypeVariable INDENT TraitInterfaceStatementList DEDENT', 
        -> new TraitInterface($2, $3, $5)
  ]
  
  TraitImplementation: [
    o 'TRAIT CAPID Type INDENT TraitImplementationStatementList DEDENT', 
        -> new TraitImplementation($2, $3, $5)
  ]

  TraitInterfaceStatement: [
    o 'ID : Type', -> new TraitInterfaceSymbolType($1, $3)
    o 'FunctionBinding', -> new transformTo("TraitInterfaceFunctionBinding", $1) 
    o 'SymbolBinding', -> new transformTo("TraitInterfaceSymbolBinding", $1)
  ]
  
  TraitImplementationStatement: [
    o 'FunctionBinding', -> new transformTo("TraitImplementationStatementBinding", $1)
    o 'SymbolBinding', -> new transformTo("TraitImplementationSymbolBinding", $1)
  ]

  TraitInterfaceStatementList: [
    o 'TraitInterfaceStatement TERMINATOR', -> [$1]
    o 'TraitInterfaceStatement TERMINATOR TraitInterfaceStatementList', -> [$1].concat($3)
  ]
  
  TraitImplementationStatementList: [
    o 'TraitImplementationStatement TERMINATOR', -> [$1]
    o 'TraitImplementationStatement TERMINATOR TraitImplementationStatementList', -> [$1].concat($3)
  ]
  
  TypeTraits: [
    o '', -> []
    o 'TRAITS ( CapIdList )', -> $3      
  ]
  
  CapIdList: 
    r 'CAPID', min: 1, join: ',', name: 'CapIdList'
  
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

  BlockOrExpression: [
    o 'Block'
    o 'Expression'
  ]

  TypedArgumentList: 
    r 'TypedArgument', join: ',', min: 1

  TypedArgument: [
    o 'ID : Type', -> new TypedArgument($1, $3)
  ]

  Expression: [
    o 'InnerExpression', -> new Expression($1)
  ]
  
  InnerExpression: [
    o 'Symbol'
    o 'Value'
    o 'Value ( FunctionArgumentList )', -> new FunctionCall($1, $3)
    o 'Literal'
    o 'UnaryOp'
    o 'BinaryOp'
  ]
  
  Value: [
    o 'ParenExpression'
    o 'FunctionCall'
  ]
  
  ParenExpression: [
    o '( Expression )', -> new ParenExpression($2)
  ]

  FunctionCall: [
    o 'ID ( )', -> new FunctionCall(new Symbol($1), [])
    o 'ID ( FunctionArgumentList )', -> new FunctionCall(new Symbol($1), $3)
    o 'CAPID ( FunctionArgumentList )', -> new FunctionCall(new Symbol($1), $3)
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
    o '( NamedTupleArgumentList )', -> new TupleType($2)
    o '( NamedTupleArgumentList ) -> Type', -> new FunctionType($2, $5)
    o 'TypeVariable'
  ]

  NamedTupleArgumentList: 
    r 'NamedTupleArgument', join: ',', min: 0

  NamedTupleArgument: [
    o 'Type', -> new TypedArgument('', $1)
    o 'ID : Type', -> new TypedArgument($1, $3)
  ]
  
  TypeList:
    r 'Type', name: 'TypeList', min: 1, join: ','

  TupleTypeList: 
    r 'Type', name: 'TupleTypeList', min: 1, join: ','

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
