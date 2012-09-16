#!/usr/bin/blynx

# Scenario: we have a text file with lines describing a book or magazine 
# with its title and ISBN code. Example:
#
#     $ cat >publications.txt <<EOF 
#     book | 9781560273332 | Standard AMT Logbook
#     book | 9780760331749 | How to Weld
#     magazine | 1748-7188 | Algorithms for molecular biology
#     EOF
#
# The script would validate these publication codes:
#
#     $ blynx validate-publications.bl publications.txt
#     Book 'Standard AMT Logbook' (9781560273332) -- valid
#     Book 'How to Weld' (9780760331749) -- invalid
#     Magazine 'Algorithms for molecular biology' (1748-7188) -- valid

export(Publication, valid?)
 
import fs
import re
import sys

type Publication traits(Eq) =
  Book(title: String, isbn: String) |
  Magazine(name: String, issn: String)

interface Show of Publication
  str(publication: Publication): String =
    match publication
      Book as book -> "Book <#{book$title}> (#{book$isbn})"
      Magazine as magazine -> "Magazine <#{magazine$name}> (#{magazine$issn})"

valid?(publication: Publication): Bool =
  match publication
    Book(isbn=isbn) -> isbn.validIsbn13?
    Magazine(issn=issn) -> issn.validIssn?

validIsbn13?(isbn13: String): Bool =
  # An ISBN-13 has 12 digits and a check digit:
  #
  # x13 = (10 - (x1 + 3*x2 + x3 + 3*x4 + ... + x11 + 3*x12) mod 10) mod 10
  match isbn13.matches?("^\d{13}$")
    False -> False
    True -> 
      xs = isbn13.map(int)
      factors = [1, 3].cycle(6)
      terms = [x*factor for (x, factor) in xs.slice(0, 12).zip(factors)]
      expected_x12 = (10 - (terms.sum % 10)) % 10
      xs.get(12) == expected_x12

validIssn?(issn: String): Bool =
  # An ISSN number is an eight digit number (divided by a hyphen into 
  # two four-digit numbers), being the last one the check_digit: 
  # 
  # x8 = 11 - ((x1*8 + x2*7 + x3*6 + ... + x7*2) mod 11)
  match issn.capture("^(\d{4})-(\d{4})$")
    Nothing -> False
    Just([xs1, xs2]) ->
      xs = (xs1 ++ xs2).map(int)
      terms = [x*idx for (x, idx) in xs[0..6].zip([8..2,-1])]
      check_digit = 11 - (terms.sum % 11)
      expected_x7 = match check_digit
        11 -> "0"
        10 -> "X"
        other -> other.str
      issn.get(8) == expected_x7

getPublicationsFromFile(path: String): impure [Publication] =
  parseLine(line: String): Maybe(Publication) =
    fields = line.split("|").map(strip)
    match fields
      ["book", isbn13, title] -> Just(Book(title=title, isbn13=isb13))
      ["magazine", issn, name] -> Just(Magazine(name=name, issn=issn))
      other -> Nothing
  fs@readFileSync(path).lines.map(parseLine).compact

main() =
  match sys@args
    [] -> 
      stderr("validate-publications.bl FILE1 [FILE2 ...]")
      sys@exit(1)
    paths -> 
      paths.each(path ->
        getPublicationsFromFile(path).each(publication ->
          state = if publication.valid? then "valid" else "invalid"
          print("#{publication} -- #{state}")
        )
      )
