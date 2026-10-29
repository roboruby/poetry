# frozen_string_literal: true

require "test_helper"

# Strict validation's code half: limits, topology, identifiers, calls and
# composition, and the strict session that refuses an update whole.
class StrictTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI
  Strict = A2UI::Strict
  BASIC = A2UI::Catalogs::Basic::ID

  # A binding with composition constraints in its definitions.
  class Constrained < A2UI::Catalogs::Basic
    def definition(name)
      { "Column" => { "allowedChildren" => %w[Text] }, "Text" => { "allowedParents" => %w[Column Surface] } }[name]
    end
  end

  def surface(catalog = A2UI::Catalogs::Basic.new)
    A2UI::Surface.new(id: "s", catalog: catalog, catalog_id: BASIC)
  end

  def deep(levels) = levels.times.reduce("leaf") { |inner, _| { "k" => inner } }

  def test_limits_on_nesting_calls_and_paths
    assert_nil Strict.limit_problem({ "value" => deep(49) })
    assert_equal "RECURSION_ERROR", Strict.limit_problem({ "value" => deep(51) })[:code]
    call = 6.times.reduce({ "@path" => "/x" }) { |inner, _| { "@call" => "f", "args" => { "v" => inner } } }

    assert_match(/functionCall depth > 5/, Strict.limit_problem(call)[:message])
    assert_equal "Invalid path syntax: 'a~2b'", Strict.limit_problem({ "@path" => "a~2b" })[:message]
    assert_nil Strict.limit_problem({ "@path" => "items/0/name" })
  end

  def test_topology_names_the_missing_root_the_dangling_field_and_the_orphan
    s = surface

    assert_match(/Missing root component/,
                 Strict.topology_problems({ "a" => { "id" => "a", "component" => "Text" } }, s).first[:message])
    tabs = { "root" => { "id" => "root", "component" => "Tabs", "tabs" => [{ "title" => "A", "child" => "gone" }] } }

    assert_equal "Component 'root' references non-existent component 'gone' in field 'tabs[0].child' " \
                 "(Dangling reference 'gone' in component 'root')", Strict.topology_problems(tabs, s).first[:message]
    loose = { "root" => { "id" => "root", "component" => "Column", "children" => [] },
              "stray" => { "id" => "stray", "component" => "Text", "text" => "x" } }

    assert_match(/Orphaned component 'stray'/, Strict.topology_problems(loose, s).first[:message])
  end

  def test_identifiers_and_calls
    s = surface

    assert_equal(["Component id '9x' must be a valid UAX #31 identifier"],
                 Strict.identifier_problems([{ "id" => "9x" }], A2UI::Dialect::V1_0).map do |problem|
                   problem[:message]
                 end)
    assert_empty Strict.identifier_problems([{ "id" => "9x" }], A2UI::Dialect::V0_9), "v0.9 ids are any string"
    text = ->(call) { [{ "id" => "root", "component" => "Text", "text" => call }] }

    assert_equal "Unrecognized function 'shout'",
                 Strict.call_problems(text.call({ "@call" => "shout", "args" => {} }), s).first[:message]
    assert_equal "Invalid argument 'pattern' for regex: expected string",
                 Strict.call_problems(text.call({ "@call" => "regex", "args" => { "value" => "a", "pattern" => 5 } }),
                                      s).first[:message]
    assert_empty Strict.call_problems(text.call({ "@call" => "@index", "args" => {} }), s)
  end

  def test_composition_follows_the_catalog_definitions
    s = surface(Constrained.new)
    set = { "root" => { "id" => "root", "component" => "Column", "children" => %w[b] },
            "b" => { "id" => "b", "component" => "Button", "child" => "t" } }

    assert_equal(["UNALLOWED_CHILD"], Strict.composition_problems(set, s).map { |problem| problem[:code] })
    assert_match(/Allowed children: \['Text'\]\./, Strict.composition_problems(set, s).first[:message])
  end

  def test_a_strict_session_refuses_an_update_whole
    session = A2UI::Session.new(strict: true)
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s", "components" => [
                    { "id" => "root", "component" => "Column", "children" => %w[later] }
                  ] } })

    assert_empty session.surface("s").components, "a dangling reference refuses the update"
    assert_match(/Dangling reference 'later'/, session.errors.last.dig("error", "message"))
    assert_equal "INTEGRITY_ERROR", session.errors.last.dig("error", "code")

    relaxed = A2UI::Session.new
    relaxed.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    relaxed.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s", "components" => [
                    { "id" => "root", "component" => "Column", "children" => %w[later] }
                  ] } })

    assert_equal %w[root], relaxed.surface("s").components.keys, "streaming delivers children later"
  end

  def test_one_message_naming_an_id_twice_is_refused_in_any_mode
    session = A2UI::Session.new
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    session.apply({ "version" => "1.0", "updateComponents" => { "surfaceId" => "s", "components" => [
                    { "id" => "root", "component" => "Text",
                      "text" => "a" }, { "id" => "root", "component" => "Text", "text" => "b" }
                  ] } })

    assert_equal "Duplicate component ID: 'root'", session.errors.last.dig("error", "message")
    assert_empty session.surface("s").components
  end
end
