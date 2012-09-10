#!/usr/bin/blynx

# Imagine we have a text file where each line describes a book or magazines 
# with their title and ISBN codes:
#
#     $ cat >publications.txt <<EOF 
#     book | 9781560273332 | Standard AMT Logbook
#     book | 9780760331749 | How to Weld
#     magazine | 1748-7188 | Algorithms for molecular biology
#     EOF
#
# The script simply validates these publication codes:
#
#     $ blynx validate-publications.bl publications.txt
#     Book 'Standard AMT Logbook' (9781560273332) -- valid
#     Book 'How to Weld' (9780760331749) -- invalid
#     Magazine 'Algorithms for molecular biology' (1748-7188) -- valid

export(Publication, isValid)
 
import fs
import sys
import re(search)

type Publication traits(Eq) =
  Book(title: String, isbn: String) |
  Magazine(name: String, issn: String)

trait Show Publication
  str(publication: Publication): String =
    match publication
      Book as book -> "Book <#{book$title}> (#{book$isbn})"
      Magazine as magazine -> "Magazine <#{magazine$name}> (#{magazine$issn})"

isValid(publication: Publication): Bool =
  match publication
    Book(isbn=isbn) -> isbn.isIsbn13Valid
    Magazine(issn=issn) -> issn.isIssnValid

isIsbn13Valid(isbn13: String): Bool =
  # An ISBN-13 has 12 digits and a check digit:
  #
  # x13 = (10 - (x1 + 3*x2 + x3 + 3*x4 + ... + x11 + 3*x12) mod 10) mod 10
  if not isbn13.search("^\d{13}$")
    return False
  xs = isbn13.chars.map(int)
  factors = [1, 3].cycle(6)
  terms = [x*factor for (x, factor) in xs.slice(0, 12).zip(factors)]
  expected_x12 = (10 - (terms.sum % 10)) % 10
  xs.get(12) == expected_x12

isIssnValid(issn: String): Bool =
  # An ISSN number is an eight digit number (divided by a hyphen into 
  # two four-digit numbers), being the last one the check_digit: 
  # 
  # x8 = 11 - ((x1*8 + x2*7 + x3*6 + ... + x7*2) mod 11)
  if not issn.search("^\d{4}-\d{4}$")
    return False
  xs = (issn.slice(0, 3).chars ++ issn.slice(5, 7).chars).map(int)
  terms = [x*idx for (x, idx) in xs.slice(0, 6).zip([8..2,-1])]
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
  fs@readFileSync(path, "utf8").lines.map(parseLine).compact

main() =
  sys@args.each(path ->
    getPublicationsFromFile(path).each(publication ->
      state = if publication.isValid then "valid" else "invalid"
      print("#{publication} -- #{state}")
    )
  )
