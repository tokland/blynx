#!/usr/bin/coffee
_ = require './underscore_extensions'
{debug, error} = require './lib'

# Escape special characters of regular expression in string: 'ab*' -> 'ab\\*'
escapeRegExp = (s) -> 
  s.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")

# Split string and build a OR-ed regular expression with it: 'if then' -> /if|then/
b = (s) -> 
  new RegExp(_(s.split(" ")).map((c) -> escapeRegExp(c)).join("|"))

operator_symbols = "= + - & | ^ < > ! : * / %".split(" ")

isolated = (s) ->
  s2 = _(s.split(" ")).map(escapeRegExp).join("|") 
  new RegExp("(#{s2})(?:[^#{escapeRegExp(operator_symbols.join(""))}]|$)")
  
# Group symbol operators with argument as first character
op = (c) ->  
  new RegExp("#{escapeRegExp(c)}[#{escapeRegExp(operator_symbols.join(""))}]*")

keywords = (s) ->
  new RegExp(_(s.split(" ")).map((s2) -> "\\b#{s2}\\b").join("|"))
  
# {tokenName: RegExp}
tokensDefinition = 
  _KEYWORDS: keywords("type if then else external as return match case yield")
  
  _SYMBOLS_GROUPERS: b("( [ { } ] )")
  _SYMBOLS_INTERNAL1: b("-> => , ; ... .. . $ @")
  _SYMBOLS_INTERNAL2: isolated("|= &=")
  _SYMBOLS_INTERNAL3: isolated(": = & ! |")

  SYMBOL_EQUAL: op("=")  
  SYMBOL_PLUS: op("+")
  SYMBOL_MINUS: op("-")
  SYMBOL_CIRCUMFLEX: op("^")
  SYMBOL_LESS: op("<")
  SYMBOL_MORE: op(">")
  SYMBOL_EXCLAMATION: op("!")
  SYMBOL_COLON: op(":")
  SYMBOL_MUL: op("*")
  SYMBOL_DIV: op("/")
  SYMBOL_PERCENT: op("%")
  SYMBOL_AMPERSAND: op("&")
  SYMBOL_PIPE: op("|")
  
  TERMINATOR: /()\s*\n+/
  WHITESPACE: /[ \t]+/
  
  STRING: /"(?:[^"\\]|\\.)*"/
  COMMENT: /(?:#)(.*)/
  ID: /[a-z_]\w*/
  CAPID: /[A-Z]\w*/
  FLOAT: /[0-9]+\.(?:[0-9]+)/
  INTEGER: /[0-9]+/

# get parseState and extract [token, newParseState]
#
# parseState -- {source, lineNumber})
# token -- [tag, stringValue, lineNumber]
getToken = (parseState) ->
  [consumed, token] = _.mapDetect(tokensDefinition, (regexp, token_name) ->
    flags = _.last(regexp.toString().split("/"))
    complete_regexp = new RegExp("^(?:" + regexp.source + ")", flags)
    if (match = parseState.source.match(complete_regexp))
      captured = (if match[1] == undefined then match[0] else match[1])
      name = if token_name.match(/^_/) then captured.toUpperCase() else token_name
      token = [name, captured, parseState.lineNumber]
      # REFACTOR: don't consume non-capturing tailing groups 
      consumed = if match[1] and match[0][0] == match[1][0] then match[1] else match[0]
      [consumed, token]
    else
      false
  ) or error("LexerError", "Cannot parse: '" + parseState.source + "'")
  new_parse_state =
    source: parseState.source.slice(consumed.length)
    lineNumber: parseState.lineNumber + (consumed.match(/\n/g)?.length or 0)
  [token, new_parse_state]

# ideas: find unmatching groupers, remove newlines on grouped, line-continuators (\)

filterTokens = (tokens) ->
  tokens_out = []
  push = (ts) -> tokens_out.push(ts...)
  state = {indent_stack: [0], start_line: true}

  # Ensure TERMINATOR+EOF tail
  if _.isEmpty(tokens)
    tokens.push(["EOF", "", 0])
  else
    last_token = _(tokens).last()
    tokens.push(["TERMINATOR", "", last_token[2]]) if last_token[0] != "TERMINATOR"
    tokens.push(["EOF", "", last_token[2]])
  
  # Add tokens INDENT/DEDENT from WHITESPACE tokens 
  for token, index in tokens 
    output_tail = if token[0] == "WHITESPACE" then [] else [token]
    new_state = if state.start_line
      new_indent = if token[0] == "WHITESPACE" then token[1].length else 0
      if new_indent > _(state.indent_stack).last()
        while _(tokens_out).last()?[0] == "TERMINATOR"
          tokens_out.pop()
        push([["INDENT", "", token[2]], output_tail...])
        {start_line: false, indent_stack: [state.indent_stack..., new_indent]} 
      else if new_indent < _(state.indent_stack).last()
        idx = state.indent_stack.indexOf(new_indent)
        unless idx >= 0
          error("LexerError", "no indent level found: #{new_indent}")
        levels_dedented = state.indent_stack.length - idx - 1
        close_paren_on_dedent = token[0] in [")", "]"] or tokens[index+1]?[0] in [")", "]"]
        is_keyword = (token[0] == "ELSE" or 
          (token[0] == "WHITESPACE" and tokens[index+1]?[0] == "ELSE"))
        add_terminator = (close_paren_on_dedent or is_keyword)
        dedents = _.flatten1([
          [["DEDENT", "", token[2]]],
          (if add_terminator then [] else [["TERMINATOR", "", token[2]]]),
        ])
        dedent_tokens = _.flatten1(_(dedents).repeat(levels_dedented))
        push([dedent_tokens..., output_tail...])
        {start_line: false, indent_stack: state.indent_stack.slice(0, idx+1)} 
      else
        push(output_tail)
        {start_line: false}
    else
      unless token[0] == "WHITESPACE"
        push([token])
      {start_line: (token[0] == "TERMINATOR")}
    _(state).update(new_state)
    
  tokens_out
  
# Return array of tokens from source code
exports.tokenize = (source) ->
  parseState = {source: source, lineNumber: 1}
  tokens = while parseState.source
    [token, parseState] = getToken(parseState)
    token
  filterTokens(tokens)
