# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    class RegistryTest < Minitest::Test
      def registry
        # The shared builder the rake task generates from - the sync test
        # must verify the exact same construction (helpers section included).
        Poetry::Ui.registry
      end

      def test_discovers_poetry_ui_components
        expected = %w[poetry/ui/accordion poetry/ui/alert poetry/ui/alert_dialog poetry/ui/aspect_ratio
                      poetry/ui/attachment poetry/ui/autocomplete poetry/ui/avatar poetry/ui/badge
                      poetry/ui/breadcrumb poetry/ui/bubble
                      poetry/ui/button poetry/ui/button_group poetry/ui/calendar poetry/ui/card poetry/ui/carousel
                      poetry/ui/checkbox poetry/ui/clipboard_text poetry/ui/code_block
                      poetry/ui/collapsible
                      poetry/ui/combobox poetry/ui/command poetry/ui/command/dialog poetry/ui/context_menu
                      poetry/ui/data_table poetry/ui/date_field poetry/ui/date_picker
                      poetry/ui/deferred poetry/ui/dialog poetry/ui/drawer
                      poetry/ui/dropdown_menu
                      poetry/ui/empty
                      poetry/ui/field poetry/ui/field_group poetry/ui/field_separator
                      poetry/ui/fieldset poetry/ui/file_input
                      poetry/ui/hover_card
                      poetry/ui/icon poetry/ui/input poetry/ui/input_group poetry/ui/input_otp poetry/ui/item
                      poetry/ui/kbd
                      poetry/ui/label
                      poetry/ui/link poetry/ui/marker poetry/ui/menubar poetry/ui/message poetry/ui/message_scroller
                      poetry/ui/metadata_list poetry/ui/meter
                      poetry/ui/native_select poetry/ui/navigation_menu poetry/ui/number_field
                      poetry/ui/pagination poetry/ui/popover poetry/ui/progress poetry/ui/questionnaire
                      poetry/ui/radio_group
                      poetry/ui/resizable
                      poetry/ui/scroll_area
                      poetry/ui/search_field poetry/ui/select
                      poetry/ui/sensitive_input
                      poetry/ui/separator poetry/ui/sheet poetry/ui/sidebar poetry/ui/skeleton poetry/ui/slider
                      poetry/ui/spinner poetry/ui/stat
                      poetry/ui/switch poetry/ui/table poetry/ui/tabs poetry/ui/tag_group
                      poetry/ui/textarea poetry/ui/time_field poetry/ui/timeline poetry/ui/toast
                      poetry/ui/toast_trigger
                      poetry/ui/toaster
                      poetry/ui/toggle poetry/ui/toggle_group poetry/ui/toolbar poetry/ui/tooltip poetry/ui/tree
                      poetry/ui/typeset]

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
