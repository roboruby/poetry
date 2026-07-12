# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Field
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_field(**)
          component = Component.new(id: "field-probe", label_text: "Email newsletter",
                                    hint: "Sent weekly.", **)
          render_inline(component) do
            %(<button type="button" role="checkbox" id="field-probe">x</button>).html_safe
          end.to_html
        end

        def test_vertical_is_the_default_orientation
          root = doc(render_field).at_css("[data-slot=field]")

          assert_equal "vertical", root["data-orientation"]
          assert_includes root["class"], "cn-field-orientation-vertical"
        end

        def test_horizontal_reorders_the_grid_around_a_boolean_control
          root = doc(render_field(orientation: :horizontal)).at_css("[data-slot=field]")

          assert_equal "horizontal", root["data-orientation"]
          assert_includes root["class"], "cn-field-orientation-horizontal"
          # The layout rides the dictionary (upstream cva parity): control
          # auto-places left, label pins to column 2, hint stacks under it.
          assert_includes root["class"], "grid-cols-[auto_1fr]"
          assert_includes root["class"], "[&>[data-slot=label]]:col-start-2"
          assert_includes root["class"], "[&>[data-slot=field-hint]]:col-start-2"
          # DOM order is unchanged - label first (the for= association).
          assert_equal %w[label field-hint], root.css("[data-slot]").map { |el| el["data-slot"] } - ["field"],
                       "the grid reorders visually, never the DOM"
        end

        def test_orientation_is_a_registry_surfaced_style
          orientation = Component.prop_definitions[:styles].find { |style| style[:name] == :orientation }

          assert_equal %i[vertical horizontal], orientation[:variants]
          assert_equal :vertical, orientation[:default]
        end

        def test_the_aria_quartet_survives_orientation
          html = render_field(orientation: :horizontal, error: "can't be blank", required: true)
          field = Component.new(id: "field-probe", label_text: "x", hint: "h", error: "e", required: true)

          assert_includes html, %(data-invalid="true")
          assert_equal "field-probe-error field-probe-hint", field.control_attributes["aria-describedby"]
          assert doc(html).at_css("label[for=field-probe]"), "label keeps its for= target"
        end
      end
    end
  end
end
