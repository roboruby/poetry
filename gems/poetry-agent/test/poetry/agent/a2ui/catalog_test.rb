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
          assert card["properties"].key?("children"), "the card body is a content cell"
          refute card["properties"].key?("content_class"), "styling escape hatches stay out"

          badge = catalog.components.fetch("Badge")

          assert_equal [{ "required" => ["text"] }, { "required" => ["children"] }], badge["anyOf"]
          assert_equal "AlertDialog", catalog.component_name("poetry/ui/alert_dialog")
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
