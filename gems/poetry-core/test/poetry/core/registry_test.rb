# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class RegistryTest < Minitest::Test
      # The requires_content shape: one declaration drives the
      # runtime raise AND the registry's static contract.
      module ContentProbe
        class Component < Poetry::Core::Component
          requires_content "the probe body"

          def call
            content_tag(:span, content)
          end
        end
      end

      def registry
        # Explicit component list: descendant discovery inside the test suite
        # would pick up test-defined probe components.
        Registry.new(components: [Poetry::Core::X::Component, Poetry::Core::Generic::Component])
      end

      def test_entries_are_keyed_by_component_path
        assert_equal %w[poetry/core/generic poetry/core/x], registry.entries.keys.sort
      end

      def test_entry_carries_the_introspected_surface
        entry = registry.entries.fetch("poetry/core/x")

        assert_equal "Poetry::Core::X::Component", entry["class_name"]
        assert_equal "poetry-core-x", entry["bem_block"]
        color = entry["styles"].find { |style| style["name"] == "color" }

        assert_includes color["variants"], "indigo"
        assert_equal "indigo", color["default"]
        assert_equal Poetry::Core::X::Style.capsule, entry["capsule"]
      end

      def test_yaml_is_plain_data_with_no_ruby_tags
        yaml = registry.to_yaml

        refute_includes yaml, "!ruby", "symbols must be stringified for language-agnostic consumers"
        parsed = YAML.safe_load(yaml)

        assert parsed["components"].key?("poetry/core/x")
      end

      def test_generate_and_verify_round_trip
        Dir.mktmpdir do |dir|
          refute registry.verified?(root: dir), "missing registry must not verify"
          registry.generate!(root: dir)

          assert registry.verified?(root: dir)

          File.write(File.join(dir, Registry::RELATIVE_PATH), "components: {}\n")

          refute registry.verified?(root: dir), "tampering must be detected"
        end
      end

      def test_helpers_section_is_emitted_when_given_and_absent_otherwise
        contracts = {
          "poetry_widget_addon" => {
            "options" => [{ "name" => "align", "type" => :symbol, "variants" => %i[inline-start inline-end] }]
          },
          "poetry_widget_group" => {}
        }
        with_helpers = Registry.new(components: [Poetry::Core::X::Component], helpers: contracts)
        parsed = YAML.safe_load(with_helpers.to_yaml)

        assert_equal %w[poetry_widget_addon poetry_widget_group], parsed["helpers"].keys
        align = parsed.dig("helpers", "poetry_widget_addon", "options").first

        assert_equal %w[inline-start inline-end], align["variants"], "helper contracts must be plain data"
        refute_includes with_helpers.to_yaml, "!ruby"
        refute YAML.safe_load(registry.to_yaml).key?("helpers"), "no helpers given means no helpers key"
      end

      def test_blocks_section_is_emitted_when_given_and_absent_otherwise
        blocks = {
          "data-index" => { "title" => "Data index", "description" => "A records screen.",
                            "components" => %w[badge table], "template" => "blocks/data_index.html.erb" }
        }
        with_blocks = Registry.new(components: [Poetry::Core::X::Component], blocks: blocks)
        parsed = YAML.safe_load(with_blocks.to_yaml)

        assert_equal %w[badge table], parsed.dig("blocks", "data-index", "components")
        assert_equal "blocks/data_index.html.erb", parsed.dig("blocks", "data-index", "template")
        refute YAML.safe_load(registry.to_yaml).key?("blocks"), "no blocks given means no blocks key"
      end

      def test_requires_content_is_emitted_when_declared_and_absent_otherwise
        entries = Registry.new(components: [ContentProbe::Component, Poetry::Core::X::Component]).entries
        probe = entries.fetch(ContentProbe::Component.component_path)

        assert_equal "the probe body", probe["requires_content"]
        refute entries.fetch("poetry/core/x").key?("requires_content"),
               "no declaration means no requirement claimed"
      end

      def test_ensure_content_raises_the_declared_hint
        component = ContentProbe::Component.new
        def component.content? = false
        error = assert_raises(ArgumentError) { component.ensure_content! }

        assert_equal "ContentProbe requires a content block (the probe body)", error.message
        def component.content? = true

        assert_nil component.ensure_content!
      end

      def test_committed_registry_is_in_sync_with_source
        # The CI drift gate as a unit test: default discovery filters to
        # components whose source lives in this gem, so the set is identical
        # here and under the rake task's fresh boot.
        assert_predicate Registry.new, :verified?,
                         "committed component registry drifted - run `bin/rake registry:generate` and commit"
      end
    end
  end
end
