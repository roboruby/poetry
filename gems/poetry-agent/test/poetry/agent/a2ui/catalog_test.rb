# frozen_string_literal: true

require "test_helper"
require "poetry/ui"

module Poetry
  module Agent
    module A2UI
      # The registry projected as an A2UI v1.0 catalog: the document obeys
      # the catalog rules and each component carries what the registry knows.
      class CatalogTest < Minitest::Test
        def catalog
          @catalog ||= Catalog.from_registry(Poetry::Ui.root)
        end

        def test_the_document_obeys_the_v1_catalog_rules
          doc = catalog.to_h

          keys = %w[$schema $id protocolVersion title description catalogId instructions components functions $defs]

          assert_equal keys,
                       doc.keys
          assert_equal "1.0", doc["protocolVersion"]
          assert_equal Catalog::DEFAULT_ID, doc["catalogId"]
          assert_equal %w[anyComponent anyFunction], doc["$defs"].keys
          refs = doc.dig("$defs", "anyComponent", "oneOf").map { |ref| ref["$ref"].delete_prefix("#/components/") }

          assert_equal doc["components"].keys, refs
          assert_equal({ "propertyName" => "component" }, doc.dig("$defs", "anyComponent", "discriminator"))
          doc["components"].each do |name, schema|
            assert_match Catalog::NAME_PATTERN, name
            assert_equal name, schema.dig("properties", "component", "const")
            assert_includes schema["required"], "component"
            schema["properties"].each_key { |property| assert_match Catalog::NAME_PATTERN, property }
          end

          assert_operator doc["components"].size, :>, 70
          assert_equal doc["components"].keys, doc["components"].keys.sort
          assert_equal JSON.parse(catalog.to_json), doc
        end

        def test_components_carry_axes_options_slots_content_and_actions
          button = catalog.components.fetch("Button")

          assert_equal %w[default destructive outline secondary ghost link], button.dig("properties", "variant", "enum")
          assert_equal "default", button.dig("properties", "variant", "default")
          disabled = button.dig("properties", "disabled")

          assert_match(/Disables the control/, disabled["description"])
          assert_equal({ "type" => "boolean",
                         "default" => false }, disabled.except("description"))
          assert_equal "#{COMMON_TYPES}DynamicString", button.dig("properties", "label", "$ref")
          assert_equal "#{COMMON_TYPES}ComponentId", button.dig("properties", "leading", "$ref")
          assert_equal "#{COMMON_TYPES}Action", button.dig("properties", "action", "$ref")
          assert_equal "#{COMMON_TYPES}ChildList", button.dig("properties", "children", "$ref")
          assert_match(/Rules: Use poetry_button/, button["description"])
          refute button["properties"].key?("class")

          card = catalog.components.fetch("Card")

          assert_equal "#{COMMON_TYPES}ComponentId", card.dig("properties", "title", "$ref")
          assert card["properties"].key?("children"), "the card renders its block"
          refute card["properties"].key?("content_class"), "styling escape hatches stay out"
          assert catalog.components.fetch("Field")["properties"].key?("children"), "a Field's block is its control"
          refute catalog.components.fetch("Tabs")["properties"].key?("children"), "Tabs fill from their slots"
          refute catalog.components.fetch("Input")["properties"].key?("children")

          badge = catalog.components.fetch("Badge")

          refute badge.key?("anyOf"), "v1.0's meta-schema refuses a root anyOf; the renderer requires the content"
          assert_match(/Give it text or children\./, badge["description"])
          assert_equal "AlertDialog", catalog.component_name("poetry/ui/alert_dialog")
        end

        def test_the_v1_0_document_obeys_the_catalog_meta_schema
          require "json_schemer"
          path = "../../../fixtures/a2ui/upstream/specification/v1_0/json/catalog_definition.json"
          meta = JSON.parse(File.read(File.expand_path(path, __dir__)))
          drafts = JSONSchemer::Draft202012::Meta::SCHEMAS.to_h { |uri, schema| [uri.to_s, schema] }
          drafts[JSONSchemer::Draft202012::BASE_URI.to_s] = JSONSchemer::Draft202012::SCHEMA
          schemer = JSONSchemer.schema(meta, ref_resolver: proc { |uri| drafts.fetch(uri.to_s.sub(/#.*\z/, "")) })
          problems = schemer.validate(catalog.to_h).map { |error| "#{error["data_pointer"]} #{error["type"]}" }

          assert_empty problems.first(5)
        end

        def test_the_v0_9_document_is_the_same_catalog_in_v0_9s_form
          doc = catalog.to_h(version: "v0.9")

          assert_equal Catalog::V0_9_ID, doc["catalogId"]
          assert_equal %w[$schema $id title description catalogId components functions $defs], doc.keys
          assert_equal %w[CatalogComponentCommon theme anyComponent anyFunction], doc["$defs"].keys
          assert_equal catalog.components.keys, doc["components"].keys
          text = doc.dig("components", "Button", "allOf")

          assert_equal "#{COMMON_TYPES_V0_9}ComponentCommon", text[0]["$ref"]
          assert_equal "#{COMMON_TYPES_V0_9}DynamicString", text[2].dig("properties", "label", "$ref")
          assert_equal({ "const" => "boolean" }, doc.dig("functions", "email", "properties", "returnType"))
          refute_includes JSON.generate(doc), "\"$ref\":\"common_types.json", "every common type is named absolutely"
          assert_equal Catalog::V0_9_ID, catalog.inline(version: "v0.9")["catalogId"]
          assert_raises(ArgumentError) { Catalog.new(entries: {}, catalog_id: "urn:x").to_h(version: "v0.9") }
        end

        def test_inline_form_and_exclusions
          inline = catalog.inline

          assert_equal %w[catalogId components], inline.keys
          assert_equal catalog.components.keys, inline["components"].keys

          entries = { "poetry/ui/badge" => { "description" => "A badge.", "requires_content" => "text" },
                      "poetry/ui/kbd" => { "description" => "A key." } }
          trimmed = Catalog.new(entries: entries, exclude: ["poetry/ui/kbd"], catalog_id: "urn:test")

          assert_equal %w[Badge], trimmed.components.keys
          assert_equal "urn:test", trimmed.to_h["$id"]
          assert_raises(ArgumentError) { Catalog.from_registry("/nowhere") }
        end
      end
    end
  end
end
