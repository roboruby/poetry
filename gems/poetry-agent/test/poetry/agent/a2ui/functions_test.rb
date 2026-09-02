# frozen_string_literal: true

require "test_helper"

# The basic function set, the evaluator, and check evaluation.
class FunctionsTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI

  def surface(data = {}, components: [])
    A2UI::Surface.new(id: "s", catalog: A2UI::Catalogs::Basic.new, data: data, components: components)
  end

  def evaluator(data = {}, scope: nil, errors: nil)
    A2UI::Evaluator.new(surface(data), scope, on_error: errors && ->(message) { errors << message })
  end

  def test_validators_return_validation_results
    ev = evaluator

    assert_equal({ "valid" => true }, ev.call("required", { "value" => "x" }))
    assert_equal({ "valid" => false }, ev.call("required", { "value" => "  " }))
    assert_equal({ "valid" => false }, ev.call("required", { "value" => [] }))
    assert_equal({ "valid" => false }, ev.call("required", { "value" => nil }))
    assert_equal({ "valid" => true },
                 ev.call("regex", { "value" => "+12345678901", "pattern" => "^\\+?[0-9]{10,15}$" }))
    assert_equal({ "valid" => false }, ev.call("regex", { "value" => "abc", "pattern" => "^[0-9]+$" }))
    assert_equal({ "valid" => true }, ev.call("length", { "value" => "abcd", "min" => 2, "max" => 4 }))
    assert_equal({ "valid" => false }, ev.call("length", { "value" => "abcde", "max" => 4 }))
    assert_equal({ "valid" => true }, ev.call("numeric", { "value" => "7.5", "min" => 1, "max" => 10 }))
    assert_equal({ "valid" => false }, ev.call("numeric", { "value" => "seven" }))
    assert_equal({ "valid" => true }, ev.call("email", { "value" => "ada@example.com" }))
    assert_equal({ "valid" => false }, ev.call("email", { "value" => "ada@example" }))
  end

  def test_an_invalid_pattern_is_a_function_error
    errors = []

    assert_nil evaluator(errors: errors).call("regex", { "value" => "x", "pattern" => "(" })
    assert_match(/function "regex": regex:/, errors.first)
  end

  def test_number_formatting
    ev = evaluator

    assert_equal "1,234,567.891", ev.call("formatNumber", { "value" => 1_234_567.891 })
    assert_equal "1234.50", ev.call("formatNumber", { "value" => 1234.5, "decimals" => 2, "grouping" => false })
    assert_equal "12", ev.call("formatNumber", { "value" => "12.0" })
    assert_equal "", ev.call("formatNumber", { "value" => "n/a" })
  end

  def test_currency_formatting
    ev = evaluator

    assert_equal "$14.50", ev.call("formatCurrency", { "value" => 14.5, "currency" => "USD" })
    assert_equal "-€1,234.57", ev.call("formatCurrency", { "value" => -1234.567, "currency" => "eur" })
    assert_equal "¥5,000", ev.call("formatCurrency", { "value" => 5000, "currency" => "JPY" })
    assert_equal "SEK 9.99", ev.call("formatCurrency", { "value" => 9.99, "currency" => "SEK" })
    assert_equal "$1", ev.call("formatCurrency", { "value" => 1.4, "currency" => "USD", "decimals" => 0 })
  end

  def test_date_formatting
    ev = evaluator

    assert_equal "Sep 1, 18:05",
                 ev.call("formatDate", { "value" => "2026-09-01T18:05:00Z", "format" => "MMM d, HH:mm" })
    assert_equal "Tuesday, September 1, 2026 at 12:00 AM",
                 ev.call("formatDate", { "value" => "2026-09-01", "format" => "EEEE, MMMM d, yyyy 'at' h:mm a" })
    assert_equal "2025-09-01", ev.call("formatDate", { "value" => 1_756_750_000_000, "format" => "yyyy-MM-dd" })
    assert_equal "2025-09-01", ev.call("formatDate", { "value" => 1_756_750_000, "format" => "yyyy-MM-dd" })
    assert_equal "", ev.call("formatDate", { "value" => "garbage", "format" => "yyyy" })
    assert_equal "", ev.call("formatDate", { "value" => nil, "format" => "yyyy" })
  end

  def test_pluralize_follows_the_english_categories
    ev = evaluator
    forms = { "one" => "item", "other" => "items" }

    assert_equal "item", ev.call("pluralize", forms.merge("value" => 1))
    assert_equal "items", ev.call("pluralize", forms.merge("value" => 2))
    assert_equal "items", ev.call("pluralize", forms.merge("value" => 0))
    assert_equal "none", ev.call("pluralize", forms.merge("value" => 0, "zero" => "none"))
    assert_equal "pair", ev.call("pluralize", forms.merge("value" => 2, "two" => "pair"))
    assert_equal "items", ev.call("pluralize", forms.merge("value" => "many"))
  end

  def test_open_url_allows_http_only
    errors = []
    ev = evaluator(errors: errors)

    assert_equal "https://example.com/docs", ev.call("openUrl", { "url" => "https://example.com/docs" })
    assert_nil ev.call("openUrl", { "url" => "javascript:alert(1)" })
    assert_match(/only http and https/, errors.last)
  end

  def test_combinators_read_validation_results_and_booleans
    ev = evaluator

    assert ev.call("and", { "values" => [true, { "valid" => true }, "yes"] })
    refute ev.call("and", { "values" => [true, { "valid" => false }] })
    assert ev.call("or", { "values" => [false, nil, { "valid" => true }] })
    refute ev.call("or", { "values" => [false, "false", "0", ""] })
    assert ev.call("not", { "value" => false })
    refute ev.call("not", { "value" => "true" })
  end

  def test_missing_required_arguments_and_unknown_functions_are_errors
    errors = []
    ev = evaluator(errors: errors)

    assert_nil ev.call("regex", { "value" => "x" })
    assert_nil ev.call("frobnicate", {})
    assert_equal ['function "regex": regex: missing pattern', 'function "frobnicate": unknown function "frobnicate"'],
                 errors
  end

  def test_arguments_resolve_bindings_calls_and_interpolated_strings
    ev = evaluator({ "n" => 3, "user" => { "name" => "Ada" } })

    assert_equal "Total: $3.00 for 3 items",
                 ev.argument("Total: ${formatCurrency(value: ${/n}, currency: 'USD')} for ${/n} " \
                             "${pluralize(value: ${/n}, one: 'item', other: 'items')}")
    assert_equal [3, "Ada"], ev.argument([{ "path" => "/n" }, { "path" => "/user/name" }])
    assert_equal({ "nested" => "Ada" }, ev.argument({ "nested" => "${/user/name}" }))
    assert_equal "plain", ev.argument("plain")
  end

  def test_format_string_interpolates_through_resolve
    ev = evaluator({ "reviewCount" => 2847 })
    value = { "call" => "formatString",
              "args" => { "value" => "(${formatNumber(value: ${/reviewCount})} " \
                                     "${pluralize(value: ${/reviewCount}, one: 'review', other: 'reviews')})" } }

    assert_equal "(2,847 reviews)", ev.resolve(value)
  end

  def test_index_is_only_available_in_a_template_scope
    errors = []

    assert_equal "#3", evaluator(scope: "/rows/2").interpolate("#${@index(offset: 1)}")
    assert_equal 2, evaluator(scope: "/rows/2").call("@index", {})
    assert_equal "", evaluator(errors: errors).interpolate("${@index()}")
    assert_match(/only available inside a template/, errors.first)
  end

  def test_malformed_interpolation_warns_and_renders_nothing
    errors = []

    assert_equal "", evaluator(errors: errors).interpolate("${oops")
    assert_match(/formatString: expected "}"/, errors.first)
  end

  def test_stringify_follows_the_conversion_rules
    ev = evaluator

    assert_equal "", ev.stringify(nil)
    assert_equal "12", ev.stringify(12.0)
    assert_equal "12.5", ev.stringify(12.5)
    assert_equal "true", ev.stringify(true)
    assert_equal '{"a":[1]}', ev.stringify({ "a" => [1] })
  end

  def test_checks_yield_failures_with_messages_and_severities
    s = surface({ "email" => "nope", "terms" => "" })
    ev = A2UI::Evaluator.new(s)
    component = { "id" => "x",
                  "checks" => [
                    { "condition" => { "call" => "email", "args" => { "value" => { "path" => "/email" } } },
                      "message" => "Invalid email format" },
                    { "condition" => { "call" => "required", "args" => { "value" => { "path" => "/terms" } } } },
                    { "condition" => { "path" => "/result" } },
                    { "condition" => { "call" => "not", "args" => { "value" => false } } }
                  ] }
    s.update_data("/result",
                  { "valid" => false, "code" => "SOFT", "message" => "Just a note", "severity" => "warning" })

    assert_equal [{ valid: false, code: nil, message: "Invalid email format", severity: "error" },
                  { valid: false, code: nil, message: "Check failed", severity: "error" }],
                 A2UI::Checks.failures(component, ev)
  end

  def test_the_catalog_declares_the_function_set
    schema = A2UI::Functions.basic.schema

    assert_equal %w[required regex length numeric email formatString formatNumber formatCurrency formatDate pluralize
                    openUrl and or not], schema.keys
    assert_equal "validationResult", schema["length"]["returnType"]
    assert_equal "length", schema["length"]["allOf"][1]["properties"]["call"]["const"]
    assert_equal %w[value], schema["length"]["allOf"][1]["properties"]["args"]["required"]
    assert schema["openUrl"]["requiresUserActivation"]
    assert_equal "rendererOnly", schema["email"]["allowedCallers"]
    assert_equal 14, A2UI::Functions.basic.any_function["oneOf"].length
    refute A2UI::Functions.basic.agent_callable?("email")
    assert_raises(ArgumentError) { A2UI::Functions.new.define("x", description: "", returns: "string", callers: "anyone") }
  end
end
