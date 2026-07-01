# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class RegistryTest < Minitest::Test
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
