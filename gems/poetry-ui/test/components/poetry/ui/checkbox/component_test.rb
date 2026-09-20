# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Checkbox
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_checkbox(**)
          render_inline(Component.new(**)).to_html
        end

        def test_the_data_slot_trio_renders_with_the_store_inversion
          fragment = doc(render_checkbox(name: "terms"))
          control = fragment.css('button[data-slot="checkbox"]').first
          indicator = fragment.css('[data-slot="checkbox-indicator"]').first
          input = fragment.css('input[data-slot="checkbox-input"]').first

          assert_equal "checkbox", control["data-component"]
          assert_equal "checkbox", control["role"]
          assert_equal "button", control["type"]
          assert_equal "false", control["aria-checked"]
          # Base UI checked pair: bare data-unchecked, never data-checked.
          assert control.key?("data-unchecked")
          refute control.key?("data-checked")
          assert indicator.key?("data-unchecked")
          refute indicator.key?("data-checked")
          assert_equal "true", indicator["aria-hidden"]
          # THE form participant + the store: server-rendered, sr-only, out
          # of the accessibility tree (the button is the accessible control).
          assert_equal "checkbox", input["type"]
          assert_equal "terms", input["name"]
          assert_equal "1", input["value"]
          assert_equal "true", input["aria-hidden"]
          assert_equal "-1", input["tabindex"]
          assert_includes input["class"], "sr-only"
          refute input.key?("checked")
        end

        def test_the_controller_wires_the_button_to_the_input_by_stable_id
          control = doc(render_checkbox(name: "terms")).css('[data-slot="checkbox"]').first

          assert_equal "poetry--core--checked", control["data-controller"]
          assert_equal "click->poetry--core--checked#toggle", control["data-action"]
          assert_equal "#{control["id"]}-input", control["data-poetry--core--checked-input-id-value"]
        end

        def test_the_hidden_pair_renders_unchecked_first_with_rails_values
          fragment = doc(render_checkbox(name: "terms"))
          inputs = fragment.css("input")

          # Hidden-input-first ordering (Tags::CheckBox-exact, last wins).
          assert_equal(%w[hidden checkbox], inputs.map { |input| input["type"] })
          assert_equal(%w[terms terms], inputs.map { |input| input["name"] })
          assert_equal "0", inputs.first["value"]
        end

        def test_unchecked_value_nil_suppresses_the_pair_for_the_array_idiom
          fragment = doc(render_checkbox(name: "user[roles][]", unchecked_value: nil))

          assert_empty fragment.css('input[type="hidden"]')
          assert_equal "user[roles][]", fragment.css('input[type="checkbox"]').first["name"]
        end

        def test_checked_renders_the_full_projection
          fragment = doc(render_checkbox(name: "terms", checked: true))
          control = fragment.css('[data-slot="checkbox"]').first

          assert_equal "true", control["aria-checked"]
          assert control.key?("data-checked")
          refute control.key?("data-unchecked")
          assert fragment.css('input[type="checkbox"]').first.key?("checked")
        end

        def test_indeterminate_renders_mixed_with_the_minus_glyph_and_an_unchecked_input
          fragment = doc(render_checkbox(name: "all", checked: :indeterminate))
          control = fragment.css('[data-slot="checkbox"]').first

          assert_equal "mixed", control["aria-checked"]
          assert control.key?("data-indeterminate")
          refute control.key?("data-checked")
          refute control.key?("data-unchecked")
          # POETRY ADDITION: the MinusIcon (shadcn shows a check for mixed);
          # input.checked stays false (unchecked_value submits).
          assert_includes fragment.css('[data-slot="checkbox-indicator"] svg').first.inner_html, "M5 12h14"
          refute_includes doc(render_checkbox(name: "all", checked: true))
            .css('[data-slot="checkbox-indicator"] svg').first.inner_html, "M5 12h14"
          refute fragment.css('input[type="checkbox"]').first.key?("checked")
        end

        def test_disabled_lands_on_the_button_and_both_inputs
          fragment = doc(render_checkbox(name: "terms", disabled: true))

          assert fragment.css('[data-slot="checkbox"]').first.key?("disabled")
          assert(fragment.css("input").all? { |input| input.key?("disabled") })
        end

        def test_no_name_renders_a_visual_only_control_without_inputs
          fragment = doc(render_checkbox(checked: true))
          control = fragment.css('[data-slot="checkbox"]').first

          assert_empty fragment.css("input")
          assert_nil control["data-poetry--core--checked-input-id-value"]
          assert control.key?("data-checked")
        end

        def test_required_is_aria_only_and_label_is_the_aria_label_fallback
          fragment = doc(render_checkbox(name: "terms", required: true, label: "Accept terms"))
          control = fragment.css('[data-slot="checkbox"]').first

          assert_equal "true", control["aria-required"]
          assert_equal "Accept terms", control["aria-label"]
          # Never native required: no unfocusable native validation
          # bubbles on an aria-hidden tabindex=-1 input.
          assert(fragment.css("input").none? { |input| input.key?("required") })
        end

        def test_field_control_attributes_land_on_the_button
          field = Field::Component.new(id: "signup-terms", label_text: "Terms",
                                       error: "must be accepted", required: true)
          html = render_inline(Component.new(name: "terms",
                                             **field.control_attributes.transform_keys(&:to_sym))).to_html
          control = doc(html).css('[data-slot="checkbox"]').first

          assert_equal "signup-terms", control["id"]
          assert_equal "signup-terms-error", control["aria-describedby"]
          assert_equal "true", control["aria-invalid"]
          assert_equal "true", control["aria-required"]
          # The input id derives from the FINAL (Field-issued) id.
          assert_equal "signup-terms-input", doc(html).css('input[type="checkbox"]').first["id"]
        end

        def test_source_exact_classes_land_on_the_control_and_indicator
          html = render_checkbox(name: "terms")
          control = doc(html).css('[data-slot="checkbox"]').first
          indicator = doc(html).css('[data-slot="checkbox-indicator"]').first

          %w[peer cn-checkbox shrink-0 outline-none].each do |token|
            assert_includes control["class"], token
          end
          %w[place-content-center transition-none data-unchecked:invisible].each do |token|
            assert_includes indicator["class"], token
          end
        end

        def test_caller_classes_merge_onto_the_button
          control = doc(render_checkbox(name: "terms", class: "size-5")).css('[data-slot="checkbox"]').first

          assert_includes control["class"], "size-5"
          refute_includes control["class"], "size-4"
        end
      end
    end
  end
end
