# frozen_string_literal: true

require "test_helper"

# Strict validation's schema half: the shipped specification schemas with a
# surface's catalogs plugged in, and the session that applies them.
class SchemasTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI
  Schemas = A2UI::Schemas
  V1 = A2UI::Dialect::V1_0
  V09 = A2UI::Dialect::V0_9
  BASIC = A2UI::Catalogs::Basic::ID
  UPSTREAM = File.expand_path("../../../fixtures/a2ui/upstream", __dir__)

  # A catalog with one closed component and one function.
  CUSTOM = { "catalogId" => "custom",
             "components" => { "Badge" => { "type" => "object", "additionalProperties" => false,
                                            "properties" => { "label" => { "type" => "string" } },
                                            "required" => ["label"] } },
             "functions" => { "shout" => { "type" => "object", "properties" => {
               "@call" => { "const" => "shout" },
               "args" => { "type" => "object", "properties" => { "value" => { "type" => "string" } },
                           "required" => ["value"] }
             } } } }.freeze

  def validator(dialect = V1, default: BASIC, catalogs: { BASIC => Schemas.basic_catalog(V1) })
    Schemas::Validator.new(dialect, default: default, catalogs: catalogs)
  end

  def update(*components, version: "1.0")
    { "version" => version, "updateComponents" => { "surfaceId" => "s", "components" => components } }
  end

  def examples(dir)
    Dir[File.join(UPSTREAM, dir, "*.json")].flat_map { |file| JSON.parse(File.read(file))["messages"] }
  end

  def test_the_shipped_schemas_are_the_vendored_ones
    Dir[File.join(Schemas::ROOT, "**", "*")].select { |path| File.file?(path) }.each do |path|
      relative = path.delete_prefix("#{Schemas::ROOT}/")

      assert FileUtils.identical?(path, File.join(UPSTREAM, relative)), "#{relative} differs from its vendored copy"
    end
  end

  def test_every_basic_example_passes_its_version
    v1 = validator

    assert_empty(examples("catalogs/basic/v1/examples").filter_map { |message| v1.problem(message) })
    v09 = validator(V09, default: "basic", catalogs: { "basic" => Schemas.basic_catalog(V09) })
    problems = examples("specification/v0_9/catalogs/basic/examples").filter_map { |message| v09.problem(message) }

    assert_equal ["Validation failed for component 'CustomSlider' (child-native-slider-2): (root) oneOf: " \
                  "'component' \"CustomSlider\" names no oneOf schema"], problems.map { |problem| problem[:message] },
                 "one v0.9 example uses a component the basic catalog does not have"
  end

  def test_problems_name_the_component_the_theme_or_the_message
    v1 = validator
    button = { "id" => "go", "component" => "Button", "child" => "label", "action" => { "event" => { "name" => "go" } },
               "unknownAttribute" => 1 }

    assert_equal({ code: "VALIDATION_FAILED", path: "/updateComponents/components/0/unknownAttribute",
                   message: "Validation failed for component 'Button' (go): /unknownAttribute unevaluatedProperties: " \
                            "property not allowed" }, v1.problem(update(button)))
    assert_equal "Validation failed for message: /deleteSurface/surfaceId type: expected string, received integer",
                 v1.problem({ "version" => "1.0", "deleteSurface" => { "surfaceId" => 5 } })[:message]
    v09 = validator(V09, default: "basic", catalogs: { "basic" => Schemas.basic_catalog(V09) })
    theme = { "version" => "v0.9", "createSurface" => { "surfaceId" => "s1", "catalogId" => "basic",
                                                        "theme" => { "primaryColor" => 5 } } }

    assert_match(/\AValidation failed for theme on surface 's1': /, v09.problem(theme)[:message])
  end

  def test_function_calls_are_checked_against_their_catalog
    text = { "id" => "t", "component" => "Text", "text" => { "@call" => "formatNumber", "args" => { "value" => "x" } } }

    assert_match(%r{/text/args/value type: expected}, validator.problem(update(text))[:message])
    index = { "id" => "t", "component" => "Text", "text" => { "@call" => "@index", "args" => {} } }

    assert_nil validator(default: nil).problem(update(index)), "@index is the system's on a surface with no default"
  end

  def test_the_input_alias_validates_as_the_bare_version
    text = { "id" => "t", "component" => "Text", "text" => "hi" }

    assert_nil validator.problem(update(text, version: "v1.0"))
  end

  def test_a_v1_0_component_or_call_is_checked_against_the_catalog_it_names
    v1 = validator(catalogs: { BASIC => Schemas.basic_catalog(V1), "custom" => CUSTOM })
    badge = { "id" => "b", "component" => "Badge", "catalogId" => "custom", "label" => "new" }

    assert_nil v1.problem(update(badge)), "a closed entry admits the envelope keys"
    assert_match(/'Badge'/, v1.problem(update(badge.except("catalogId")))[:message], "the default has no Badge")
    assert_match(%r{/label type}, v1.problem(update(badge.merge("label" => 5)))[:message])
    shout = { "id" => "t", "component" => "Text", "text" => { "@call" => "shout", "catalogId" => "custom",
                                                              "args" => { "value" => "hi" } } }

    assert_nil v1.problem(update(shout))
    assert_nil v1.problem(update(badge.merge("catalogId" => "elsewhere", "label" => 5))),
               "a catalog the session does not hold is the code checks' to refuse"
  end

  def test_a_catalog_without_a_document_admits_anything
    v1 = validator(default: "opaque", catalogs: { "opaque" => nil })

    assert_nil v1.problem(update({ "id" => "x", "component" => "Anything", "whatever" => [1] }))
    v09 = validator(V09, default: "opaque", catalogs: { "opaque" => nil })

    assert_nil v09.problem(update({ "id" => "x", "component" => "Anything" }, version: "v0.9"))
  end

  def test_poetrys_own_catalog_compiles_in_both_versions
    [V1, V09].each do |dialect|
      native = A2UI::Catalogs::Native.new(id: "poetry", dialect: dialect)
      v = Schemas::Validator.new(dialect, default: "poetry", catalogs: { "poetry" => native.document })
      button = { "id" => "go", "component" => "Button", "text" => "Go" }

      assert_nil v.problem(update(button, version: dialect.version)), dialect.version
    end
  end

  def test_a_strict_session_refuses_a_message_its_schema_refuses
    session = A2UI::Session.new(strict: true)
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    session.apply(update({ "id" => "root", "component" => "Text", "text" => "hi", "size" => "huge" }))

    assert_empty session.surface("s").components
    assert_equal({ "code" => "VALIDATION_FAILED", "surfaceId" => "s", "path" => "/updateComponents/components/0/size",
                   "message" => "Validation failed for component 'Text' (root): /size unevaluatedProperties: " \
                                "property not allowed" }, session.errors.last["error"])
    relaxed = A2UI::Session.new
    relaxed.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    relaxed.apply(update({ "id" => "root", "component" => "Text", "text" => "hi", "size" => "huge" }))

    assert_equal %w[root], relaxed.surface("s").components.keys
  end

  def test_the_code_checks_speak_before_the_schema
    session = A2UI::Session.new(strict: true)
    session.apply({ "version" => "1.0", "createSurface" => { "surfaceId" => "s", "catalogId" => BASIC } })
    session.apply(update({ "id" => "root", "component" => "Text", "text" => { "@call" => "nope", "args" => {} } }))

    assert_equal "Unrecognized function 'nope'", session.errors.last.dig("error", "message")
  end

  def test_v1_0_metadata_holds_only_identifier_extensions_in_any_mode
    session = A2UI::Session.new
    create = lambda { |metadata|
      { "version" => "1.0", "createSurface" => { "surfaceId" => "m", "catalogId" => BASIC, "metadata" => metadata } }
    }
    session.apply(create.call({ "owner" => "me" }))

    assert_equal "createSurface.metadata holds only 'extensions', not 'owner'",
                 session.errors.last.dig("error", "message")
    session.apply(create.call({ "extensions" => { "a2ui:experimental" => {} } }))

    assert_equal "Extension key 'a2ui:experimental' must be a valid UAX #31 identifier",
                 session.errors.last.dig("error", "message")
    assert_empty session.surfaces
    session.apply(create.call({ "extensions" => { "a2ui_experimental" => { "streaming" => true } } }))

    assert_equal %w[m], session.surfaces.keys
  end
end
