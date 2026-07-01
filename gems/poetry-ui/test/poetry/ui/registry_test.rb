# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    class RegistryTest < Minitest::Test
      def registry
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
      end

      def test_discovers_poetry_ui_components
        expected = %w[poetry/ui/alert poetry/ui/badge poetry/ui/button poetry/ui/card
                      poetry/ui/dialog poetry/ui/field poetry/ui/icon poetry/ui/input
                      poetry/ui/label poetry/ui/link]

        assert_equal expected, registry.entries.keys.sort
      end

      def test_button_entry_carries_the_golden_contract
        entry = registry.entries.fetch("poetry/ui/button")

        assert_equal "Poetry::Ui::Button::Component", entry["class_name"]
        assert_equal "poetry-ui-button", entry["bem_block"]
        variant = entry["styles"].find { |style| style["name"] == "variant" }

        assert_equal %w[default destructive outline secondary ghost link], variant["variants"]
        assert_equal Poetry::Ui::Button::Style.capsule, entry["capsule"]
      end

      def test_committed_registry_is_in_sync_with_source
        assert_predicate registry, :verified?,
                         "committed component registry drifted - run `bin/rake registry:generate` and commit"
      end

      def test_helpers_are_wired_into_action_view
        assert_includes ActionView::Base.included_modules, Poetry::Ui::ComponentsHelper
      end
    end
  end
end
