# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # N9 W1b form statics: ButtonGroup, NativeSelect, InputGroup - pure
    # markup composing with the field spine.
    class FormStaticsTest < ViewComponent::TestCase
      # -- ButtonGroup ----------------------------------------------------------

      def test_button_group_is_a_group_with_orientation
        html = render_inline(ButtonGroup::Component.new("aria-label": "Alignment")) { "buttons" }
        root = html.css('[data-slot="button-group"]').first

        assert_equal "group", root["role"]
        assert_equal "horizontal", root["data-orientation"]
        assert_equal "Alignment", root["aria-label"]
        assert_includes root["class"], "cn-button-group-orientation-horizontal",
                        "the horizontal joining classes compose (via the theme rule)"
      end

      def test_button_group_vertical_flips_the_axis
        html = render_inline(ButtonGroup::Component.new(orientation: :vertical)) { "b" }

        assert_includes html.css('[data-slot="button-group"]').first["class"],
                        "cn-button-group-orientation-vertical"
      end

      def test_button_group_requires_members
        assert_raises(ArgumentError) { render_inline(ButtonGroup::Component.new) }
      end

      # -- NativeSelect ---------------------------------------------------------

      def test_native_select_is_a_real_labelled_ready_select
        html = render_inline(NativeSelect::Component.new(
                               name: "sort", id: "sort-select",
                               options: [%w[Newest newest], %w[Oldest oldest]], selected: "oldest"
                             ))

        select = html.css("select").first

        assert_equal "sort", select["name"]
        assert_equal "sort-select", select["id"], "the id is the Label pairing hook"
        options = select.css("option")

        assert_equal(%w[newest oldest], options.map { |opt| opt["value"] })
        assert_equal "oldest", options.find { |opt| opt["selected"] }["value"]
        chevron = html.css('[data-slot="native-select-icon"]').first

        assert_equal "true", chevron["aria-hidden"], "the chevron is decorative"
      end

      def test_native_select_content_block_overrides_the_options_path
        html = render_inline(NativeSelect::Component.new(name: "grouped")) do
          "<optgroup label=\"A\"><option value=\"1\">One</option></optgroup>".html_safe
        end

        assert_equal 1, html.css("select optgroup").length
      end

      def test_native_select_states
        html = render_inline(NativeSelect::Component.new(size: :sm, disabled: true, invalid: true,
                                                         options: %w[A]))
        select = html.css("select").first

        assert_equal "sm", select["data-size"]
        assert select["disabled"]
        assert_equal "true", select["aria-invalid"]
      end

      # -- InputGroup -----------------------------------------------------------

      def test_input_group_is_a_group_surface
        html = render_inline(InputGroup::Component.new) { "control" }
        root = html.css('[data-slot="input-group"]').first

        assert_equal "group", root["role"]
        assert_includes root["class"], "cn-input-group", "the GROUP wears the field chrome (theme rule)"
      end

      def test_input_group_requires_content
        assert_raises(ArgumentError) { render_inline(InputGroup::Component.new) }
      end
    end
  end
end
