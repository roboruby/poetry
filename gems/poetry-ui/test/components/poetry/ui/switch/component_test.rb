# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Switch
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_switch(**)
          render_inline(Component.new(**)).to_html
        end

        def test_the_data_slot_trio_renders_with_switch_semantics
          fragment = doc(render_switch(name: "notifications"))
          control = fragment.css('button[data-slot="switch"]').first
          thumb = fragment.css('[data-slot="switch-thumb"]').first
          input = fragment.css('input[data-slot="switch-input"]').first

          assert_equal "switch", control["data-component"]
          assert_equal "switch", control["role"]
          assert_equal "button", control["type"]
          assert_equal "false", control["aria-checked"]
          # Base UI checked pair: bare data-unchecked, never data-checked.
          assert control.key?("data-unchecked")
          refute control.key?("data-checked")
          assert thumb.key?("data-unchecked")
          refute thumb.key?("data-checked")
          assert_equal "true", thumb["aria-hidden"]
          # The Checkbox architecture verbatim: the sr-only native input is
          # the store, out of the accessibility tree.
          assert_equal "checkbox", input["type"]
          assert_equal "true", input["aria-hidden"]
          assert_equal "-1", input["tabindex"]
          assert_includes input["class"], "sr-only"
        end

        def test_the_shared_controller_is_reused_verbatim
          control = doc(render_switch(name: "notifications")).css('[data-slot="switch"]').first

          # Zero fork: the same poetry--core--checked surface Checkbox ships.
          assert_equal "poetry--core--checked", control["data-controller"]
          assert_equal "click->poetry--core--checked#toggle", control["data-action"]
          assert_equal "#{control["id"]}-input", control["data-poetry--core--checked-input-id-value"]
        end

        def test_data_size_carries_the_variant_and_the_thumb_has_no_size_classes_of_its_own
          fragment = doc(render_switch(name: "n", size: :sm))
          control = fragment.css('[data-slot="switch"]').first
          thumb = fragment.css('[data-slot="switch-thumb"]').first

          assert_equal "sm", control["data-size"]
          # The variant travels ONCE on the root; the thumb derives sizing
          # via group-data-[size=*]/switch inside the theme rules - never
          # plain size-* utilities in markup.
          assert_includes control["class"], "cn-switch"
          assert_includes thumb["class"], "cn-switch-thumb"
          refute_match(/(?:^| )size-\d/, thumb["class"])
        end

        def test_indeterminate_raises_the_binary_contract
          error = assert_raises(ArgumentError) { Component.new(checked: :indeterminate) }

          assert_match(/strictly binary/, error.message)
        end

        def test_the_hidden_pair_renders_with_rails_values_iff_name
          fragment = doc(render_switch(name: "notifications", checked: true))
          inputs = fragment.css("input")

          assert_equal(%w[hidden checkbox], inputs.map { |input| input["type"] })
          assert_equal "0", inputs.first["value"]
          assert_equal "1", inputs.last["value"]
          assert inputs.last.key?("checked")
          assert_empty doc(render_switch).css("input"), "no name: -> visual-only, no inputs"
        end

        def test_disabled_lands_on_the_button_and_both_inputs
          fragment = doc(render_switch(name: "n", disabled: true))

          assert fragment.css('[data-slot="switch"]').first.key?("disabled")
          assert(fragment.css("input").all? { |input| input.key?("disabled") })
        end

        def test_required_is_aria_only_and_field_control_attributes_land_on_the_button
          field = Field::Component.new(id: "settings-alerts", label_text: "Alerts", hint: "Instant.")
          html = render_inline(Component.new(name: "alerts", required: true,
                                             **field.control_attributes.transform_keys(&:to_sym))).to_html
          control = doc(html).css('[data-slot="switch"]').first

          assert_equal "settings-alerts", control["id"]
          assert_equal "settings-alerts-hint", control["aria-describedby"]
          assert_equal "true", control["aria-required"]
          assert(doc(html).css("input").none? { |input| input.key?("required") })
          assert_equal "settings-alerts-input", doc(html).css('input[type="checkbox"]').first["id"]
        end

        def test_source_exact_classes_and_the_rtl_travel_addition
          fragment = doc(render_switch(name: "n"))
          control = fragment.css('[data-slot="switch"]').first
          thumb = fragment.css('[data-slot="switch-thumb"]').first

          # The structural inline set + the theme names; the track/thumb
          # treatments (sizes, checked fills, the translate travel and the
          # poetry RTL fix) live in .cn-switch / .cn-switch-thumb.
          %w[peer group/switch transition-all cn-switch].each do |token|
            assert_includes control["class"], token
          end
          %w[pointer-events-none transition-transform cn-switch-thumb].each do |token|
            assert_includes thumb["class"], token
          end
        end

        def test_label_is_the_aria_label_fallback
          control = doc(render_switch(name: "n", label: "Airplane mode")).css('[data-slot="switch"]').first

          assert_equal "Airplane mode", control["aria-label"]
        end
      end
    end
  end
end
