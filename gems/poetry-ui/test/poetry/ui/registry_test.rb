# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    class RegistryTest < Minitest::Test
      def registry
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
      end

      def test_discovers_poetry_ui_components
        expected = %w[poetry/ui/accordion poetry/ui/alert poetry/ui/alert_dialog poetry/ui/aspect_ratio
                      poetry/ui/attachment poetry/ui/avatar poetry/ui/badge poetry/ui/breadcrumb poetry/ui/bubble
                      poetry/ui/button poetry/ui/button_group poetry/ui/card poetry/ui/checkbox poetry/ui/collapsible
                      poetry/ui/combobox poetry/ui/command poetry/ui/command/dialog poetry/ui/context_menu
                      poetry/ui/data_table poetry/ui/dialog poetry/ui/dropdown_menu poetry/ui/empty poetry/ui/field
                      poetry/ui/hover_card
                      poetry/ui/icon poetry/ui/input poetry/ui/input_group poetry/ui/input_otp poetry/ui/item
                      poetry/ui/kbd
                      poetry/ui/label
                      poetry/ui/link poetry/ui/marker poetry/ui/menubar poetry/ui/message poetry/ui/message_scroller
                      poetry/ui/native_select
                      poetry/ui/pagination poetry/ui/popover poetry/ui/progress poetry/ui/radio_group poetry/ui/select
                      poetry/ui/separator poetry/ui/sheet poetry/ui/skeleton poetry/ui/slider poetry/ui/spinner
                      poetry/ui/switch poetry/ui/table poetry/ui/textarea poetry/ui/toast poetry/ui/toaster
                      poetry/ui/toggle poetry/ui/toggle_group poetry/ui/tooltip]

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
