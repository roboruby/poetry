# frozen_string_literal: true

require "test_helper"

# The A2UI regex dialect: what it matches, what it refuses, and the static
# safety check, each refusal by the protocol's token.
class RegexSubsetTest < Minitest::Test
  Subset = Poetry::Agent::A2UI::RegexSubset

  def token(pattern)
    Subset.compile(pattern)
    nil
  rescue Subset::Rejected => e
    e.token
  end

  def test_anchors_are_the_ends_of_the_value
    assert Subset.match?("^abc$", "abc")
    refute Subset.match?("^abc$", "abc\n"), "$ does not match before a trailing newline"
    refute Subset.match?("^b", "a\nb"), "^ is not a line start"
    assert Subset.match?("abc", "xxabcxx"), "an unanchored pattern searches"
  end

  def test_the_class_escapes_are_ascii_and_the_dot_skips_line_ends
    refute Subset.match?("^\\d+$", "١٢٣")
    refute Subset.match?("^\\w+$", "café")
    assert Subset.match?("^\\W$", "é")
    refute Subset.match?("\\b", "é"), "a word boundary is an ASCII one"
    assert Subset.match?("\\Bx", "ax")
    refute Subset.match?("\\bx", "ax")
    refute Subset.match?("^a.b$", "a\nb")
    refute Subset.match?("^.$", " ")
    assert Subset.match?("^.$", "😀"), "the dot takes a whole code point"
    assert Subset.match?("^\\s$", " "), "\\s is ECMAScript's white space"
    refute Subset.match?("^\\S$", "﻿")
    refute Subset.match?("^abc$", "ABC"), "matching is case-sensitive"
  end

  def test_escapes_classes_groups_and_quantifiers_of_the_dialect
    assert Subset.match?("^\\u{1F600}+$", "😀😀")
    assert Subset.match?("^\\u0041\\x42\\0$", "AB\0")
    assert Subset.match?("^[\\b\\t\\-]+$", "\b\t-"), "\\b in a class is a backspace"
    assert Subset.match?("^[^a-c]$", "\n"), "a negated class takes line ends"
    assert Subset.match?("^(?:a|b)+c\\/$", "abac/")
    assert Subset.match?("^(?=.*\\d)(?!.*x).{8,}$", "secret42")
    assert Subset.match?("^a{2,3}?$", "aaa")
    assert Subset.match?("x{0}y", "y")
    refute Subset.match?("^a{2}?$", ""), "a lazy exact count is still the count"
    assert Subset.match?("", "anything"), "the empty pattern matches"
    assert Subset.match?("a||b", "zzz"), "an empty branch matches"
    refute Subset.match?("[^\\u{0}-\\u{10FFFF}]", "a"), "a class of nothing matches nothing"
  end

  def test_what_the_dialect_leaves_out_is_unsupported_syntax
    ["(a)\\1", "\\k<n>", "(?<=a)b", "(?<!a)b", "(?<n>a)", "(?i)a", "\\p{L}", "\\cA", "\\07", "\\q", "[\\B]",
     "a{", "a}", "]", "a**", "a++", "^*", "(?=a)+", "a{2,1}", "a{,2}", "a{1", "a{99999}", "x{1,99999}",
     "[a-\\d]", "[z-a]", "[]", "[a&&b]", "[[a]]", "[a--b]", "[a", "(a", "a)", "\\", "\\x4", "\\u12",
     "\\u{}", "\\u{110000}", "\\uD83D", "\\u{D800}", "[a-"].each do |pattern|
      assert_equal "UNSUPPORTED_SYNTAX", token(pattern), pattern
    end
    assert_equal "UNSUPPORTED_SYNTAX", token("\xFF".dup.force_encoding("UTF-8")), "a pattern that is not UTF-8"
    assert_equal "UNSUPPORTED_SYNTAX", token("abc".encode("UTF-16LE"))
  end

  def test_the_safety_check_names_the_rule_a_pattern_breaks
    assert_equal "PATTERN_TOO_LONG", token("a" * 257)
    assert_nil token("a" * 256)
    { "(a+)+$" => "NESTED_QUANTIFIER", "(a*){2,5}" => "NESTED_QUANTIFIER", "(?:(?=a+)b)*" => "NESTED_QUANTIFIER",
      "(a|ab)*c" => "OVERLAPPING_ALTERNATION", "(\\d|[0-5])+" => "OVERLAPPING_ALTERNATION",
      "((a)|(ab)){1,}" => "OVERLAPPING_ALTERNATION",
      "\\d+\\d+" => "ADJACENT_OVERLAP", "\\d+\\s*\\d+" => "ADJACENT_OVERLAP", "a+(?=a)b?a*" => "ADJACENT_OVERLAP",
      "(a+)(a*)" => "ADJACENT_OVERLAP", "x(?:.*.*)" => "ADJACENT_OVERLAP" }.each do |pattern, rule|
      assert_equal rule, token(pattern), pattern
    end
    ["(?:ab+)?c", "(a+)?", "(a?)*", "(a|b)*c", "\\w+\\s+\\w+", "a+ba+", "(?:a|b){1,1000}", "a{0}a+",
     "^[a-z]+@[a-z]+\\.com$"].each { |pattern| assert_nil token(pattern), pattern }
  end

  def test_a_value_past_the_cap_does_not_match_and_a_pattern_compiles_once
    assert Subset.match?("^a+$", "a" * 4096)
    refute Subset.match?("^a+$", "a" * 4097)
    assert_same Subset.compile("^held$"), Subset.compile("^held$")
    (Subset::CACHE_SIZE + 1).times { |index| Subset.compile("^fill#{index}$") }

    refute_nil Subset.compile("^held$"), "a pattern the cache let go compiles again"
    error = assert_raises(Subset::Rejected) { Subset.match?("(a+)+$", "aaa") }

    assert_match(/\ANESTED_QUANTIFIER: /, error.message)
  end

  def test_the_native_attribute_matches_the_whole_value_where_the_pattern_searches
    assert_equal "[\\s\\S]*(?:.+@.+)[\\s\\S]*", Subset.native(".+@.+")
    assert_equal "[\\s\\S]*(?:^\\d{3}-[\\u{61}-\\u{63}\\u{7B}]+?\\u{2E}$)[\\s\\S]*",
                 Subset.native("^\\d{3}-[a-c{]+?\\.$")
    assert_equal "[\\s\\S]*(?:(?:a|\\u{28})(?=\\S)(?!\\W)\\b\\B\\u{0}{2,})[\\s\\S]*",
                 Subset.native("(a|\\()(?=\\S)(?!\\W)\\b\\B\\0{2,}")
    assert_equal "[\\s\\S]*(?:(?:(?!)))[\\s\\S]*", Subset.native("[^\\u{0}-\\u{10FFFF}]")
    assert_nil Subset.native("(a+)+$"), "a refused pattern is never handed to the browser"
    assert_nil Subset.native("(?<n>a)")
  end

  def test_a_group_around_one_quantified_atom_compiles_without_a_warning
    _out, err = capture_io do
      assert Subset.match?("^(a+)?(?:b?)*((c*))?$", "aab")
    end

    assert_empty err
  end
end
