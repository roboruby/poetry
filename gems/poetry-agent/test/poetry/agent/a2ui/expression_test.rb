# frozen_string_literal: true

require "test_helper"

class ExpressionTest < Minitest::Test
  Expression = Poetry::Agent::A2UI::Expression

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
                              [:literal, true], [:text, " "], [:literal, nil]]], tree
  end

  def test_calls_with_named_bare_and_nested_arguments
    tree = Expression.parse("${formatDate(value:${/date}, format:'yyyy-MM-dd')} ${upper(${now()})} " \
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
  end

  def test_malformed_expressions_raise
    ["${oops", "${}", "${f(}", "${f(a: 1 b: 2)}", "${'unterminated}"].each do |text|
      assert_raises(Expression::SyntaxError, text) { Expression.parse(text) }
    end
  end

  def test_nesting_is_bounded
    text = "${#{"f(" * 40}1#{")" * 40}}"

    assert_raises(Expression::SyntaxError) { Expression.parse(text) }
  end

  def test_dynamic_detects_blocks
    assert Expression.dynamic?("a ${b}")
    refute Expression.dynamic?("plain")
    refute Expression.dynamic?(nil)
  end
end
