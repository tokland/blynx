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
    o 'LET SymbolBinding', -> $2
    o 'LET FunctionBinding', -> $2
    o 'External'
  ]
  
  External: [
    o 'EXTERNAL String : Type', -> new External($2, "", $4)
    o 'EXTERNAL String AS Symbol : Type', -> new External($2, $4, $6)
  ]
  
  String: [
    o 'ID', -> new Id($1)
    o 'STRINGQ', -> new StringQ($1)
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
    o 'Symbol : Type', -> new TraitInterfaceSymbolType($1, $3)
    o 'LET FunctionBinding', -> new transformTo("TraitInterfaceFunctionBinding", $2) 
    o 'LET SymbolBinding', -> new transformTo("TraitInterfaceSymbolBinding", $2)
  ]
  
  TraitImplementationStatement: [
    o 'LET FunctionBinding', -> new transformTo("TraitImplementationStatementBinding", $2)
    o 'LET SymbolBinding', -> new transformTo("TraitImplementationSymbolBinding", $2)
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

  Trait: [
    o 'CAPID'
  ]
  
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
    o 'ExpressionMatch = BlockOrExpression', -> new SymbolBinding($1, $3)
  ]
  
  ExpressionMatch: [
    o 'ID', -> new IdMatch($1)
    o '( OpSymbol )', -> new IdMatch($2)
    o 'TupleMatch', -> new TupleMatch($1)
    o 'INTEGER', -> new IntMatch($1)
    o 'FLOAT', -> new FloatMatch($1)
    o 'STRING', -> new StringMatch($1)
    o 'AdtMatch'
    o 'ListMatch'
    o 'ArrayMatch'
  ]

  ListMatch: [
    o '[ ExpressionMatchList ListMatchOptionalTail ]', -> new ListMatch($2, $3)
  ]
  
  ListMatchOptionalTail: [
    o '', -> null
    o '| ID', -> $2
  ]

  ArrayMatch: [
    o 'A[ ExpressionMatchList ]', -> new ArrayMatch($2)
  ]
  
  AdtMatch: [
    o 'CAPID AdtArgumentListOptional', -> new AdtMatch($1, $2)
  ]
  
  AdtArgumentListOptional: [
    o '( AdtArgumentMatchList )', -> $2
    o ''
  ]
    
  AdtArgumentMatchList:
    r 'AdtArgumentMatch', min: 1, join: ','

  AdtArgumentMatch: [
    o 'ExpressionMatch', -> new AdtArgumentMatch("", $1)
    o 'ID = ExpressionMatch', -> new AdtArgumentMatch($1, $3)
  ]     

  TupleMatch: [
    o '( ExpressionMatchList )', -> $2
  ]
  
  ExpressionMatchList: 
    r 'ExpressionMatch', min: 0, join: ','
  
  FunctionBinding: [
    o 'ID ( ) : Type OptionalRestrictions = BlockOrExpression', 
      -> new FunctionBinding($1, [], $5, $8, restrictions: $6)
    o 'ID ( TypedArgumentList ) : Type OptionalRestrictions = BlockOrExpression', 
      -> new FunctionBinding($1, $3, $6, $9, restrictions: $7)
    o '( OpSymbol ) ( TypedArgumentList ) : Type OptionalRestrictions = BlockOrExpression', 
      -> new FunctionBinding($2, $5, $8, $11, restrictions: $9)
    o '( $ OpSymbol ) ( TypedArgumentList ) : Type OptionalRestrictions = BlockOrExpression', 
      -> new FunctionBinding($3, $6, $9, $12, unary: true, restrictions: $10)
  ]
  
  OptionalRestrictions: [
    o '', -> []
    o 'WHERE ( RestrictionList )', -> $3
  ]
  
  RestrictionList: 
    r 'Restriction', join: ',', min: 1
    
  Restriction: [
    o 'TypeVariable @ Trait', -> new Restriction($1, $3)
  ]
  
  OpSymbol: (
    o(symbol) for symbol in [
      'SYMBOL_EQUAL', 'SYMBOL_PLUS', 'SYMBOL_MINUS', 'SYMBOL_CIRCUMFLEX'
      'SYMBOL_TILDE', 'SYMBOL_LESS', 'SYMBOL_MORE', 'SYMBOL_EXCLAMATION'
      'SYMBOL_COLON', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT'
      'SYMBOL_AMPERSAND', 'SYMBOL_PIPE', '&', '!'
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
    o 'Symbol', -> new SymbolReplacement($1)
    o 'Symbol . Symbol FunctionArgumentListOptional', -> new FunctionCall($3, [$1].concat($4))
    o 'Value'
    o 'Value ( FunctionArgumentList )', -> new FunctionCall($1, $3)
    o 'Value . Symbol FunctionArgumentListOptional', -> new FunctionCall($3, [$1].concat($4))
    o 'Literal'
    o 'Literal . Symbol FunctionArgumentListOptional', -> new FunctionCall($3, [$1].concat($4))
    o 'UnaryOp'
    o 'BinaryOp'
    o 'IfConditional'
    o 'CaseConditional'
    o 'Match'
    o 'ListRange'
  ]
  
  Match: [
    o 'MATCH Expression INDENT MatchPairList DEDENT', -> new Match($2, $4)
  ]
  
  MatchPairList: [
    o "MatchPair TERMINATOR", -> [$1]
    o "MatchPairList MatchPair TERMINATOR", -> $1.concat($2)
  ]
  
  MatchPair: [
    o 'ExpressionMatch -> BlockOrExpression', -> new MatchPair($1, $3)
  ]
    
  ListRange: [
    o '[ Expression RangeSeparator Expression OptionalRangeStep ]', 
        -> new ListRange($2, $3, $4, $5)
  ]
  
  RangeSeparator: [
    o '..'
    o '...'
  ]
  
  OptionalRangeStep: [
    o '', -> null
    o ', Expression', -> $2
  ]
  
  IfConditional: [
    o 'IF Expression THEN Expression ELSE Expression', -> new IfConditional($2, $4, $6)
  ]

  CaseConditional: [
    o 'CASE INDENT ArrowPairList DEDENT', -> new CaseConditional($3)
  ]
  
  ArrowPairList: [
    o 'ArrowPair TERMINATOR', -> [$1] 
    o 'ArrowPairList ArrowPair TERMINATOR', -> $1.concat([$2])
  ]
  
  ArrowPair: [
    o 'Expression -> BlockOrExpression', -> new ArrowPair($1, $3)
  ]

  FunctionArgumentListOptional: [
    o '', -> []
    o '( FunctionArgumentList )', -> $2
  ]
  
  Value: [
    o 'ParenExpression'
    o 'FunctionCall'
  ]

  ParenExpression: [
    o '( Expression )', -> new ParenExpression($2)
  ]

  FunctionCall: [
    o 'ID ( )', -> new FunctionCall(new SymbolReplacement(new Symbol($1)), [])
    o 'ID ( FunctionArgumentList )', -> new FunctionCall(new SymbolReplacement(new Symbol($1)), $3)
    o 'CAPID ( FunctionArgumentList )', -> new FunctionCall(new SymbolReplacement(new Symbol($1)), $3)
  ]  
  
  Symbol: [
    o 'ID', -> new Symbol($1)
    o 'CAPID', -> new Symbol($1)
    o '( OpSymbol )', -> new Symbol($2, unary: false)
    o '( $ OpSymbol )', -> new Symbol($3, unary: true)
  ]
  
  UnaryOp:
    o("#{sym} Expression", (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY') \
      for sym in ['SYMBOL_MINUS', 'SYMBOL_PLUS', 'SYMBOL_EXCLAMATION', '!', 'SYMBOL_TILDE']
  
  BinaryOp:
    o("Expression #{sym} Expression", -> new FunctionCallFromID($2, [$1, $3])) for sym in [
      'SYMBOL_EQUAL', 'SYMBOL_PLUS', 'SYMBOL_MINUS', 'SYMBOL_CIRCUMFLEX',
      'SYMBOL_TILDE', 'SYMBOL_LESS', 'SYMBOL_MORE', 'SYMBOL_EXCLAMATION',
      '!', 'SYMBOL_COLON', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT',
      'SYMBOL_AMPERSAND', '&', 'SYMBOL_PIPE'
    ]
  
  Literal: [
    o 'INTEGER', -> new Int($1)
    o 'FLOAT', -> new Float($1)
    o 'STRING', -> new String($1)
    o 'Tuple', -> new Tuple($1)
    o 'List'
    o 'Array'
  ]
  
  List: [
    o '[ ExpressionList ListOptionalTail ]', -> new List($2, $3)
  ]

  ListOptionalTail: [
    o '', -> null
    o '| Expression', -> $2
  ]

  Array: [
    o 'A[ ExpressionList ]', -> new ArrayNode($2)
  ]
  
  ExpressionList:
    r 'Expression', min: 0, join: ','

  Tuple: [
    o '( Expression , TupleList )', -> [$2].concat($4)
  ]

  TupleList: 
    r 'Expression', name: 'TupleList', join: ',', min: 1

  Type: [
    o 'CAPID', -> new Type($1, [])
    o 'CAPID ( TypeList )', -> new Type($1, $3)
    o '[ Type ]', -> new ListType($2)
    o 'A[ Type ]', -> new ArrayType($2)
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
  ['nonassoc', 'INDENT', 'DEDENT']
  ["right", "IF", "THEN", "ELSE"],
  ['left', 'SYMBOL_AMPERSAND', '&', 'SYMBOL_PIPE']
  ['left', 'SYMBOL_LESS', 'SYMBOL_MORE']
  ['left', 'SYMBOL_CIRCUMFLEX', 'SYMBOL_TILDE']
  ['left', 'SYMBOL_EQUAL', 'SYMBOL_EXCLAMATION', '!']
  ['right', 'SYMBOL_COLON']
  ['left', 'SYMBOL_PLUS', 'SYMBOL_MINUS']
  ['left', 'SYMBOL_MUL', 'SYMBOL_DIV', 'SYMBOL_PERCENT']
  ['right', 'UNARY']
  ['left', '.']
]

exports.parser = new jison.Parser
  bnf: grammar
  operators: operators
  startSymbol: 'Root'
