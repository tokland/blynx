#!/usr/bin/blynx
import fs
import re
import sys

export(Publication, isValid)

type Publication traits(Eq, Show) =
  Book(title: String, isbn: String) |
  Magazine(name: String, issn: String)

trait Publication Show
  str(publication: Publication): String =
    match publication
      Book as book -> "Book <#{book$title}> (#{book$isbn})"
      Magazine as magazine -> "Magazine <#{magazine$name}> (#{magazine$issn})"

isValid(publication: Publication): Bool =
  match publication
    Book(isbn=isbn) -> isbn.isIsbn13Valid()
    Magazine(issn=issn) -> issn.isIssnValid()

isIsbn13Valid(isbn13: String): Bool =
  # An ISBN-13 has 12 digits and a check digit:
  #
  # x13 = (10 - (x1 + 3*x2 + x3 + 3*x4 + ... + x11 + 3*x12) mod 10) mod 10
  if !isbn13.re@match("^\d{13}$")
    return False
  xs = isbn13.splitChars().map(int)
  factors = [1, 3].repeat(6).flatten()
  terms = [x*factor for (x, factor) in xs[0...12].zip(factors)]
  expected_x12 = (10 - (terms.sum() % 10)) % 10
  xs[12] == expected_x12

isIssnValid(issn: String): Bool =
  # An ISSN number is an eight digit number (divided by a hyphen into 
  # two four-digit numbers), being the last one the check_digit: 
  # 
  # x8 = 11 - ((x1*8 + x2*7 + x3*6 + ... + x7*2) mod 11)
  if !issn.re@match("^\d{4}-\d{4}$")
    return False
  xs = (issn[0..3] ++ issn[5..7]).splitChars().map(int)
  terms = [x*idx for (x, idx) in xs[0..6].zip([8..2,-1])]
  check_digit = 11 - (terms.sum() % 11)
  expected_x7 = match check_digit { 11 -> "0"; 10 -> "X"; other -> other.str }
  issn[8] == expected_x7

getFromFile(path: String): [Publication] =
  parseLine(line: String): Maybe(Publication) =
    # Format of lines in file: "book | TITLE | ISBN13" or "magazine | NAME | ISSN"
    fields = line.split("|").map(strip)
    match fields
      ["book", isbn13, title] -> Just(Book(title=title, isbn13=isb13))
      ["magazine", issn, name] -> Just(Magazine(name=name, issn=issn))
      other -> Nothing
  fs@readFileSync(path, "utf8").splitLines().map(parseLine).compact()

main() =
  sys@args.each(|path| ->
    getFromFile(path).each(|publication| ->
      state = if publication.isValid() then "valid" else "invalid"
      print("#{publication} -- #{state}")
    )
  )
