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
          # Vertical is the base state - it emits no orientation class
          # (the empty-variant precedent; cn-field itself IS the stack).
          refute_includes root["class"].to_s, "cn-field-orientation"
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

        def test_hint_position_above_moves_the_guidance_before_the_control
          root = doc(render_field(hint_position: :above)).at_css("[data-slot=field]")

          slots = root.element_children.map { |el| el["data-slot"] || el.name }

          assert_equal "field-hint", slots[1], "hint renders between label and control: #{slots.inspect}"
          # The aria contract is untouched - visual order only.
          assert root.at_css("[data-slot=field-hint][id]")
        end

        def test_an_unknown_hint_position_raises
          error = assert_raises(ArgumentError) { render_field(hint_position: :sideways) }

          assert_match(/hint_position/, error.message)
        end

        def test_invalid_flag_flips_the_skin_without_an_error_line
          component = Component.new(id: "field-terms", label_text: "Accept terms",
                                    hint: "You must accept to continue.", invalid: true)
          root = doc(render_inline(component) { "<input id=\"field-terms\">".html_safe }.to_html)
                 .at_css("[data-slot=field]")

          # Upstream's `<Field data-invalid>` + muted FieldDescription: the
          # skin flips, the hint stays a hint, no error <p> renders.
          assert_equal "true", root["data-invalid"]
          assert_nil root.at_css("[data-slot=field-error]")
          assert root.at_css("[data-slot=field-hint]")
          attrs = component.control_attributes

          assert attrs["aria-invalid"]
          # describedby carries the hint only - never a dangling error id.
          assert_equal component.hint_id, attrs["aria-describedby"]
        end

        def test_setting_mirrors_horizontal_with_the_control_on_the_right
          root = doc(render_field(orientation: :setting)).at_css("[data-slot=field]")

          assert_equal "setting", root["data-orientation"]
          # Same themed treatment as horizontal (gap etc.) - the mirror is
          # pure structure, so no new theme hook exists for it.
          assert_includes root["class"], "cn-field-orientation-horizontal"
          assert_includes root["class"], "grid-cols-[1fr_auto]"
          # Label + hint pin LEFT; the control auto-places into column 2 on
          # the label line (upstream's content-first horizontal Field).
          assert_includes root["class"], "[&>[data-slot=label]]:col-start-1"
          assert_includes root["class"], "[&>[data-slot=field-hint]]:col-start-1"
          assert_includes root["class"], "[&>[data-slot=field-error]]:col-start-1"
        end

        def test_orientation_is_a_registry_surfaced_style
          orientation = Component.prop_definitions[:styles].find { |style| style[:name] == :orientation }

          assert_equal %i[vertical horizontal setting responsive], orientation[:variants]
          assert_equal :vertical, orientation[:default]
        end

        def test_responsive_is_container_gated_and_stacked_by_default
          root = doc(render_field(orientation: :responsive)).at_css("[data-slot=field]")

          assert_equal "responsive", root["data-orientation"]
          assert_includes root["class"], "cn-field-orientation-responsive"
          # Every layout flip rides the FieldGroup container query - below
          # the md mark (or outside any field-group scope) the field is a
          # plain vertical stack, so all placement classes carry the
          # container prefix and none appear bare.
          assert_includes root["class"], "@md/field-group:grid-cols-[1fr_auto]"
          assert_includes root["class"], "@md/field-group:[&>[data-slot=label]]:col-start-1"
          assert_includes root["class"], "@md/field-group:[&>[data-slot=field-hint]]:col-start-1"
          # The control spans the label+hint pair and centers against it
          # (upstream's FieldContent geometry on the flat quartet DOM).
          assert_includes root["class"],
                          "@md/field-group:[&>:not([data-slot=label],[data-slot=field-hint]," \
                          "[data-slot=field-error])]:row-span-2"
          refute_match(/(?<!field-group:)grid-cols-\[1fr_auto\]/, root["class"],
                       "responsive placement must stay behind the @container gate")
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
