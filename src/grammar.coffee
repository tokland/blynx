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
    o '( Symbol ) ( TypedArgumentList ) : Type = BlockOrExpression', 
        -> new FunctionBinding($2, $5, $8, $10)
    o '( $ Symbol ) ( TypedArgumentList ) : Type = BlockOrExpression', 
        -> new FunctionBinding($3, $6, $9, $11, unary: true)
  ]
  
  Symbol: [
    o "SYMBOL_EQUAL"  
    o "SYMBOL_PLUS"
    o "SYMBOL_MINUS"
    o "SYMBOL_CIRCUMFLEX"
    o "SYMBOL_TILDE"
    o "SYMBOL_LESS"
    o "SYMBOL_MORE"
    o "SYMBOL_EXCLAMATION"
    o "SYMBOL_COLON"
    o "SYMBOL_MUL"
    o "SYMBOL_DIV"
    o "SYMBOL_PERCENT"
    o "SYMBOL_AMPERSAND"
    o "SYMBOL_PIPE"
    o "&"
    o "|"
    o "!"
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
    
    o 'SYMBOL_MINUS Expression', (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY'
    o 'SYMBOL_PLUS Expression', (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY'
    o 'SYMBOL_EXCLAMATION Expression', (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY'
    o 'SYMBOL_TILDE Expression', (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY'
    o '! Expression', (-> new FunctionCallFromID($1, [$2], unary: true)), prec: 'UNARY'
    
    o 'Expression SYMBOL_EQUAL Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_PLUS Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_MINUS Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_CIRCUMFLEX Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_TILDE Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_LESS Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_MORE Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_EXCLAMATION Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression ! Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_COLON Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_MUL Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_DIV Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_PERCENT Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_AMPERSAND Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression & Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression SYMBOL_PIPE Expression', -> new FunctionCallFromID($2, [$1, $3])
    o 'Expression | Expression', -> new FunctionCallFromID($2, [$1, $3])
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

  TupleList: 
    r("Expression", name: "TupleList", join: ',')

  Type: [
    o "CAPID", -> new Type($1)
  ]

  FunctionCall: [
    o 'ID ( )', -> new FunctionCall(new Symbol($1), [])
    o 'ID ( ArgumentList )', -> new FunctionCall(new Symbol($1), $3)
  ]  

  ArgumentList: 
    r("Expression", name: "ArgumentList", min: 1, join: ',')

operators = [
  ['nonassoc',  'INDENT', 'DEDENT']
  ["left", "SYMBOL_AMPERSAND", "&", "SYMBOL_PIPE", "|"]
  ['right', 'UNARY']
  ["left", "SYMBOL_LESS", "SYMBOL_MORE"]
  ["left", "SYMBOL_CIRCUMFLEX", "SYMBOL_TILDE"]
  ["left", "SYMBOL_EQUAL", "SYMBOL_EXCLAMATION", "!"]
  ["right", "SYMBOL_COLON"]
  ["left", "SYMBOL_PLUS", "SYMBOL_MINUS"]
  ["left", "SYMBOL_MUL", "SYMBOL_DIV", "SYMBOL_PERCENT"]
]

grammar_options = 
  bnf: grammar
  operators: operators
  startSymbol: 'Root'

exports.parser = new jison.Parser(grammar_options)
