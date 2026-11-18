# frozen_string_literal: true

require "test_helper"

class ExpressionTest < Minitest::Test
  Expression = Poetry::Agent::A2UI::Expression

  def nodes(text) = Expression.parse(text)[1]

  def value(text) = nodes("${#{text}}").first[1]

  def error(text) = assert_raises(Expression::SyntaxError, text.inspect) { Expression.parse(text) }.message

  def test_plain_text_is_one_text_node
    assert_equal [:template, [[:text, "Hello"]]], Expression.parse("Hello")
    assert_equal [:template, []], Expression.parse("")
  end

  def test_paths_literals_and_escapes
    tree = Expression.parse("Hi ${/user/name}, ${firstName} ${a/b} \\${kept} ${'q,)'} ${\"d\"} ${12} ${-3.5} " \
                            "${true} ${null}")

    assert_equal [:template, [[:text, "Hi "], [:path, "/user/name"], [:text, ", "], [:path, "firstName"], [:text, " "],
                              [:path, "a/b"], [:text, " ${kept} "], [:literal, "q,)"], [:text, " "], [:literal, "d"],
                              [:text, " "], [:literal, 12], [:text, " "], [:literal, -3.5], [:text, " "],
                              [:literal, true], [:text, " "], [:literal, ""]]], tree
  end

  def test_calls_with_named_and_nested_arguments
    tree = Expression.parse("${formatDate(value:${/date}, format:'yyyy-MM-dd')} ${upper(value: ${now()})} " \
                            "${@index(offset: 1)}")

    assert_equal [:template, [
      [:call, "formatDate", { "value" => [:path, "/date"], "format" => [:literal, "yyyy-MM-dd"] }],
      [:text, " "],
      [:call, "upper", { "value" => [:call, "now", {}] }],
      [:text, " "],
      [:call, "@index", { "offset" => [:literal, 1] }]
    ]], tree
  end

  def test_quoted_strings_unescape
    assert_equal [:template, [[:literal, "it's"]]], Expression.parse("${'it\\'s'}")
    assert_equal "a\nb\tc\rd\\e\"f'gq", value("'a\\nb\\tc\\rd\\\\e\\\"f\\'g\\q'")
    assert_equal "}{", value("\"}{\"")
  end

  def test_malformed_expressions_raise
    ["${oops", "${}", "${f(}", "${f(a: 1 b: 2)}", "${'unterminated}"].each do |text|
      assert_raises(Expression::SyntaxError, text) { Expression.parse(text) }
    end
  end

  def test_number_grammar
    { "42" => 42, "007" => 7, "+1" => 1, "-0" => 0, "1.5" => 1.5, "1." => 1.0, "-42." => -42.0, ".5" => 0.5,
      "-.5" => -0.5, "+.5" => 0.5, "1e5" => 100_000.0, "2.5E+4" => 25_000.0, "1.5e-3" => 0.0015,
      "-.5E-1" => -0.05, "0e400" => 0.0, "9007199254740991" => 9_007_199_254_740_991 }.each do |text, expected|
      assert_equal expected, value(text), text
      assert_instance_of expected.class, value(text), text
    end
  end

  def test_number_range
    assert_in_delta 1e308, value("1e308")
    assert_equal Float::MAX, value("1.7976931348623158e308")
    assert_equal 10**308, value("1#{"0" * 308}")
    %w[1e-999 -1e-999 1e-99999999999999999999].each { |text| assert_predicate value(text), :zero?, text }
    %w[1e999 -1e999 2e308 1.797693134862316e308 1e99999999999999999999].each do |text|
      assert_equal "Number literal is out of range: '#{text}'", error("${#{text}}")
    end
    assert_match(/out of range/, error("${1#{"0" * 309}}"))
  end

  def test_invalid_number_literals
    %w[1.2.3 .5.5 1e 1e+ 1E- -.5e .5e+].each do |text|
      assert_equal "Invalid number literal: '#{text}'", error("${#{text}}")
    end
    assert_match(/Unexpected characters at end of expression: 'x'/, error("${-1x}"))
  end

  def test_path_characters
    %w[my-path.with_underscores a-1 a.5 ./x ../x .foo -a -. .e5 /items/.5 /items/-1 /a~1b/~0 café trueish
       true-ish null.x].each do |path|
      assert_equal [[:path, path]], nodes("${#{path}}"), path
    end
    assert_equal [[:text, "é "], [:path, "/naïve"], [:text, " ü"]], nodes("é ${ /naïve } ü")
  end

  def test_arguments_are_named_and_may_trail_a_comma
    assert_equal [[:call, "add", { "a" => [:literal, 1], "b" => [:literal, 2] }]], nodes("${add(a: 1, b: 2,)}")
    assert_equal [[:call, "f", { "x" => [:literal, ""] }]], nodes("${f(x: null)}")
    assert_equal [[:call, "now", {}]], nodes("${now ( )}")
    assert_equal "Expected ':' after argument name in function 'f': arguments are named", error("${f(1)}")
    assert_equal "Expected ':' after argument name 'a' in function 'add'", error("${add(a 1)}")
    assert_equal "Expected ',' or ')' after function arguments for 'add'", error("${add(a: 1, b: 2}")
    assert_equal "Expected ')' after function arguments for 'f'", error("${f(}")
    assert_equal "Expected ')' after function arguments for 'f'", error("${f(a: 1, }")
    assert_equal "Expected ',' or ')' after function arguments for 'f'", error("${f(a: 1 b: 2)}")
    assert_equal "Invalid function name 'a.b'", error("${a.b()}")
    assert_equal "Expected an expression, found ')'", error("${f(a: )}")
  end

  def test_error_wording
    assert_equal "Unclosed interpolation: missing '}'", error("hello ${world")
    assert_equal "Unclosed interpolation: missing '}'", error("${f(a: 'x}')")
    assert_equal "Unclosed interpolation: missing '}'", error("${ ${a }")
    assert_equal "Unexpected characters at end of expression: 'false'", error("${true false}")
    assert_equal "Unexpected characters at end of expression: 'ß'", error("ü ${a ß}")
    assert_equal "Expected an expression, found '}'", error("${}")
  end

  def test_nesting_is_bounded_at_one_hundred
    assert_equal [[:path, "x"]], nodes("#{"${" * 100}x#{"}" * 100}")
    assert_match(/\AMax recursion depth reached/, error("#{"${" * 101}1#{"}" * 101}"))
    assert_match(/\AMax recursion depth reached/, error("${#{"f(a: " * 101}1#{")" * 101}}"))
    calls = ->(node) { node[0] == :call ? 1 + node[2].values.sum { |arg| calls.call(arg) } : 0 }

    assert_equal 99, calls.call(nodes("${#{"f(a: " * 99}1#{")" * 99}}").first)
    assert_match(/\AMax recursion depth reached/, error("${#{"f(a: " * 100}1#{")" * 100}}"))
  end

  def test_sources_are_read_as_utf8
    assert_equal [[:path, "/café"]], nodes("${/caf\xC3\xA9}".b)
    assert_equal [[:path, "a"]], nodes("${a}".encode("UTF-16LE"))
    ["${/a\xFF}".dup.force_encoding(Encoding::UTF_8), "\x00\xD8".dup.force_encoding(Encoding::UTF_16LE)].each do |text|
      assert_equal "Expression is not valid UTF-8", error(text)
    end
  end

  def test_dynamic_detects_blocks
    assert Expression.dynamic?("a ${b}")
    refute Expression.dynamic?("plain")
    refute Expression.dynamic?(nil)
  end
end
