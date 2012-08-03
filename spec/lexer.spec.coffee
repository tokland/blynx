should = require 'should'
lexer = require 'lexer'
_ = require 'underscore_extensions'
{debug, error, simpleTokens} = require 'lib'

complete = (expected) ->
  {key: "complete", expected: expected}
  
tests = [
  # EOF   
  ["",
    complete("EOF")]
      
  [ "1",
    complete("[INTEGER 1] TERMINATOR EOF")]

  ["1\n",
    complete("[INTEGER 1] TERMINATOR EOF")]

  ["1\n\n2\n\n\n",
    complete("[INTEGER 1] TERMINATOR [INTEGER 2] TERMINATOR EOF")]

  # Whitespaces
  
  ["1 2  \t 3  \t  \t  4 ",
    "[INTEGER 1] [INTEGER 2] [INTEGER 3] [INTEGER 4]"]
  
  # Indentation
  
  ["""
    11
      21
      22
        (31
          41
        )
      23
  """, [
    "[INTEGER 11] INDENT [INTEGER 21] TERMINATOR [INTEGER 22]"
    "INDENT ( [INTEGER 31] INDENT [INTEGER 41]"
    "TERMINATOR DEDENT ) TERMINATOR DEDENT TERMINATOR"
    "[INTEGER 23] TERMINATOR DEDENT"
  ]]

  ["""
    11

      21
  """, [
    "[INTEGER 11] INDENT [INTEGER 21] TERMINATOR DEDENT"
  ]]

  ["1\n\n2\n\n5",
    "[INTEGER 1] TERMINATOR [INTEGER 2] TERMINATOR [INTEGER 5]"]
  
  # Literals
  
  ["1 2.2 333",
    "[INTEGER 1] [FLOAT 2.2] [INTEGER 333]"]
    
  ['"hello \\"there\\""',
    """[STRING "hello \\"there\\""]"""]

  ['x=1\n#my comment\n1',
    "[ID x] = [INTEGER 1] TERMINATOR [COMMENT my comment] TERMINATOR [INTEGER 1]"]

  ['4 #hello',
    "[INTEGER 4] [COMMENT hello]"]

  ['abc String xyz',
    "[ID abc] [CAPID String] [ID xyz]"]
  
  ['{x => 1, y => 2}',
    "{ [ID x] => [INTEGER 1] , [ID y] => [INTEGER 2] }"],

  ['if True then 1 else 2', 
    "[IF if] [CAPID True] [THEN then] [INTEGER 1] [ELSE else] [INTEGER 2]"]

  ["""
    if True 
      1 
    else 
      2
   """, [
    "[IF if] [CAPID True] INDENT [INTEGER 1] TERMINATOR DEDENT",
    "[ELSE else] INDENT [INTEGER 2] TERMINATOR DEDENT"]]

  ['|x| -> x', 
    "| [ID x] | -> [ID x]"]

  ['(1,2)',
    "( [INTEGER 1] , [INTEGER 2] )"]

  ["(())",
    "( ( ) )"]

  ["value$field",
    "[ID value] $ [ID field]"]

  ["[1, 2][1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 1] ]"]

  ["[1, 2][0..1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 0] .. [INTEGER 1] ]"]

  ["[1, 2][0...1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 0] ... [INTEGER 1] ]"]
  
  ["{a: 1}",
   "{ [ID a] : [INTEGER 1] }"]

  ["x.a()",
    "[ID x] . [ID a] ( )"]

  ["&& ||",
    "[SYMBOL_AMPERSAND &&] [SYMBOL_PIPE ||]"]

  ["> >= < <= ==", 
    "[SYMBOL_MORE >] [SYMBOL_MORE >=] [SYMBOL_LESS <] [SYMBOL_LESS <=] [SYMBOL_EQUAL ==]"]

  ["~1", 
    "[SYMBOL_TILDE ~] [INTEGER 1]"]

  ["10*2+10/5-10%2", [
    "[INTEGER 10] [SYMBOL_MUL *] [INTEGER 2] [SYMBOL_PLUS +] [INTEGER 10]"
    "[SYMBOL_DIV /] [INTEGER 5] [SYMBOL_MINUS -] [INTEGER 10] [SYMBOL_PERCENT %] [INTEGER 2]"
  ]]
  
  ["!x", 
    "! [ID x]"],

  ["x & y",
    "[ID x] & [ID y]"],

  ["x | y", 
    "[ID x] | [ID y]"],
  
  # Functions
  
  ["f(x: Int, y: Int): Float =", 
    "[ID f] ( [ID x] : [CAPID Int] , [ID y] : [CAPID Int] ) : [CAPID Float] ="]
  
  ["typed = 1",
    "[ID typed] = [INTEGER 1]"]

  ["($-)(x: Int): Int = -x", 
    "( $ [SYMBOL_MINUS -] ) ( [ID x] : [CAPID Int] ) : [CAPID Int] = [SYMBOL_MINUS -] [ID x]"]
    
  # Keywords
  
  ["type Bool = True | False", 
    "[TYPE type] [CAPID Bool] = [CAPID True] | [CAPID False]"]

  ["external alert as myalert =", 
    "[EXTERNAL external] [ID alert] [AS as] [ID myalert] ="]

  ["return 1",
    "[RETURN return] [INTEGER 1]"]

  ["yield 1",
    "[YIELD yield] [INTEGER 1]"]
    
  ["match 1",
    "[MATCH match] [INTEGER 1]"]

  ["case",
    "[CASE case]"]

  ["trait traits traitinterface",
    "[TRAIT trait] [TRAITS traits] [TRAITINTERFACE traitinterface]"]
]

tokens = (args...) ->
  simpleTokens(lexer.tokenize(args...))

describe "lexer", ->
  for test in tests
    [source, expected0] = test
    do (source, expected0) ->
      tail = " TERMINATOR EOF"
      expected = if typeof expected0 == "object"
        if expected0.key == "complete"
          expected0.expected 
        else
          expected0.join(" ") + tail
      else 
        expected0 + tail
        
      it "should return expected tokens", ->
        tokens(source).should.eql(expected, "Failed on: #{JSON.stringify(source)}")
