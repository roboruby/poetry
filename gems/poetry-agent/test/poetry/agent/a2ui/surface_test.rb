# frozen_string_literal: true

require "test_helper"

class SurfaceTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI

  def surface(components: [], data: nil)
    A2UI::Surface.new(id: "s", catalog: A2UI::Catalogs::Basic.new, catalog_id: A2UI::Catalogs::Basic::ID,
                      data: data, components: components)
  end

  def test_update_components_upserts_by_id_and_bumps_the_version
    s = surface

    assert_equal 0, s.version

    assert_empty s.update_components([{ "id" => "root", "component" => "Text", "text" => "a" }])
    assert_equal "a", s.root["text"]
    assert_equal 1, s.version

    s.update_components([{ "id" => "root", "component" => "Text", "text" => "b" }])

    assert_equal "b", s.root["text"]
    assert_equal 2, s.version
  end

  def test_component_validation_errors
    errors = surface.update_components([{ "component" => "Text" }, { "id" => "x" },
                                        { "id" => "y", "component" => "1a" },
                                        { "id" => "z", "component" => "Surface" }, "nope"])

    assert_equal(%w[/components/0 /components/1/component /components/2/component /components/3/component
                    /components/4],
                 errors.map { |error| error[:path] })
    assert(errors.all? { |error| error[:code] == "VALIDATION_FAILED" })
    assert_match(/reserved/, errors[3][:message])
  end

  def test_cycles_are_errors_but_dangling_references_are_not
    s = surface
    errors = s.update_components([{ "id" => "root", "component" => "Column", "children" => %w[a missing] },
                                  { "id" => "a", "component" => "Column", "children" => ["b"] },
                                  { "id" => "b", "component" => "Column", "children" => ["a"] }])

    assert_equal 1, errors.length
    assert_equal "/components/a", errors.first[:path]
    assert_match(/circular reference: root -> a -> b -> a/, errors.first[:message])
  end

  def test_data_updates_follow_upsert_semantics
    s = surface(data: { "user" => { "name" => "Ada" } })
    s.update_data("/user/name", "Bob")
    s.update_data("/user/email", "bob@example.com")

    assert_equal({ "user" => { "name" => "Bob", "email" => "bob@example.com" } }, s.data)

    s.update_data("/user/email", nil)

    assert_equal({ "user" => { "name" => "Bob" } }, s.data)

    s.update_data(nil, { "fresh" => true })

    assert_equal({ "fresh" => true }, s.data)

    s.update_data("/", "not an object")

    assert_empty s.data
  end

  def test_resolve_and_text_follow_the_conversion_rules
    s = surface(data: { "name" => "Ada", "n" => 3, "ok" => true, "list" => [1], "obj" => { "a" => 1 },
                        "users" => [{ "name" => "Grace" }] })

    assert_equal "Ada", s.resolve({ "path" => "/name" })
    assert_equal "literal", s.resolve("literal")
    assert_nil s.resolve({ "call" => "formatString", "args" => {} })
    assert_equal "Grace", s.resolve({ "path" => "name" }, "/users/0")
    assert_equal "3", s.text({ "path" => "/n" })
    assert_equal "true", s.text({ "path" => "/ok" })
    assert_equal "", s.text({ "path" => "/missing" })
    assert_equal "[1]", s.text({ "path" => "/list" })
    assert_equal '{"a":1}', s.text({ "path" => "/obj" })
  end

  def test_expand_handles_ids_lists_and_templates
    s = surface(data: { "tracks" => [{ "t" => 1 }, { "t" => 2 }] })

    assert_equal [["a", nil]], s.expand("a")
    assert_equal [["a", "/x"], ["b", "/x"]], s.expand(%w[a b], "/x")
    assert_equal [["tpl", "/tracks/0"], ["tpl", "/tracks/1"]], s.expand({ "componentId" => "tpl", "path" => "/tracks" })
    assert_empty s.expand({ "componentId" => "tpl", "path" => "/nope" })
    assert_empty s.expand({ "path" => "/tracks" })
    assert_empty s.expand(nil)
  end

  def test_walk_instantiates_templates_and_inputs_resolve_absolute_paths
    s = surface(data: { "items" => [{ "qty" => 1 }, { "qty" => 2 }] },
                components: [{ "id" => "root", "component" => "List",
                               "children" => { "componentId" => "row", "path" => "/items" } },
                             { "id" => "row", "component" => "Column", "children" => ["qty"] },
                             { "id" => "qty", "component" => "TextField", "label" => "Qty", "variant" => "number",
                               "value" => { "path" => "qty" } }])
    order = []
    s.walk { |component, scope| order << [component["id"], scope] }

    assert_equal [["root", nil], ["row", "/items/0"], ["qty", "/items/0"], ["row", "/items/1"], ["qty", "/items/1"]],
                 order
    assert_equal [{ path: "/items/0/qty", kind: :number }, { path: "/items/1/qty", kind: :number }], s.inputs
  end

  def test_walk_survives_a_cycle
    s = surface(components: [{ "id" => "root", "component" => "Column", "children" => ["root"] }])
    seen = []
    s.walk { |component, _scope| seen << component["id"] }

    assert_equal ["root"], seen
  end

  def test_to_h_snapshots_the_surface
    s = surface(data: { "a" => 1 }, components: [{ "id" => "root", "component" => "Text", "text" => "x" }])
    snapshot = s.to_h

    assert_equal "s", snapshot["surfaceId"]
    assert_equal A2UI::Catalogs::Basic::ID, snapshot["catalogId"]
    assert_equal 1, snapshot["version"]
    assert_equal({ "a" => 1 }, snapshot["dataModel"])
    assert_equal(["root"], snapshot["components"].map { |component| component["id"] })
  end
end
