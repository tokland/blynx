should = require 'should'
lexer = require 'lexer'
_ = require 'underscore_extensions'
{debug, error, simpleTokens} = require 'lib'

complete = (expected) ->
  {key: "complete", expected: expected}
  
tests = [ 
  ["",
    complete("EOF")]
      
  [ "1",
    complete("[INTEGER 1] TERMINATOR EOF")]

  ["1\n",
    complete("[INTEGER 1] TERMINATOR EOF")]

  ["1\n\n2\n\n\n",
    complete("[INTEGER 1] TERMINATOR [INTEGER 2] TERMINATOR EOF")]

  ["1 2  \t 3  \t  \t  4 ",
    "[INTEGER 1] [INTEGER 2] [INTEGER 3] [INTEGER 4]"]

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
  
  ["1 22 333",
    "[INTEGER 1] [INTEGER 22] [INTEGER 333]"]

  ['"hello \\"there\\""',
    """[STRING "hello \\"there\\""]"""]

  ['x=1\n# my comment\n1',
    "[ID x] = [INTEGER 1] TERMINATOR [COMMENT  my comment] TERMINATOR [INTEGER 1]"]

  ['4 #hello',
    "[INTEGER 4] [COMMENT hello]"]

  ['abc String xyz',
    "[ID abc] [ID_CAP String] [ID xyz]"]

  ['if True then 1 else 2', 
    "[IF if] [ID_CAP True] [THEN then] [INTEGER 1] [ELSE else] [INTEGER 2]"]

  ["""
    if True 
      1 
    else 
      2
   """, [
    "[IF if] [ID_CAP True] INDENT [INTEGER 1] TERMINATOR DEDENT",
    "[ELSE else] INDENT [INTEGER 2] TERMINATOR DEDENT"]]

  ['1 10.1 2000',
    "[INTEGER 1] [FLOAT 10.1] [INTEGER 2000]"]

  ['|x| -> 2*x', 
    "| [ID x] | -> [INTEGER 2] [MATH_OP *] [ID x]"]

  [', ;',
    ", ;"]

  ["()",
    "( )"]

  ["[1, 2][1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 1] ]"]

  ["[1, 2][0..1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 0] .. " + 
    "[INTEGER 1] ]"]

  ["[1, 2][0...1]",
    "[ [INTEGER 1] , [INTEGER 2] ] [ [INTEGER 0] ... " + 
    "[INTEGER 1] ]"]
  
  ["{a: 1}",
   "{ [ID a] : [INTEGER 1] }"]

  ["record.a",
    "[ID record] . [ID a]"]

  ["True && False || True",
    "[ID_CAP True] [BOOL_OP &&] [ID_CAP False] [BOOL_OP ||] [ID_CAP True]"]

  ["> >= < <= ==", 
    "[COMPARE_OP >] [COMPARE_OP >=] [COMPARE_OP <] [COMPARE_OP <=] [COMPARE_OP ==]"]

  ["10*2+10/5-10%2", [
    "[INTEGER 10] [MATH_OP *] [INTEGER 2] + [INTEGER 10]"
    "[MATH_OP /] [INTEGER 5] - [INTEGER 10] [MATH_OP %] [INTEGER 2]"
  ]]
 
  ["type Bool = True | False", 
    "[TYPE type] [ID_CAP Bool] = [ID_CAP True] | [ID_CAP False]"]

  ["external alert as myalert =", 
    "[EXTERNAL external] [ID alert] [AS as] [ID myalert] ="]

  ["return 1",
    "[RETURN return] [INTEGER 1]"]
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
