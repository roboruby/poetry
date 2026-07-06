# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Slider
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_slider(**)
          doc(render_inline(Component.new(name: "volume", label: "Volume", **)).to_html)
        end

        def test_the_slider_anatomy_renders_with_the_machine_on_the_root
          fragment = render_slider(value: 25)
          root = fragment.css('[data-slot="slider"]').first

          assert_equal "slider", root["data-component"]
          assert_equal "poetry--core--slider", root["data-controller"]
          assert_equal "pointerdown->poetry--core--slider#pointerdown", root["data-action"]
          assert_equal "horizontal", root["data-orientation"]
          %w[0 100 1].zip(%w[min max step]).each do |expected, key|
            assert_equal expected, root["data-poetry--core--slider-#{key}-value"]
          end
          assert_equal "[25]", root["data-poetry--core--slider-value-value"]
          assert_predicate fragment.css('[data-slot="slider-track"]'), :any?
          assert_predicate fragment.css('[data-slot="slider-range"]'), :any?
          assert_equal(%w[track range], %w[track range].map do |name|
            fragment.css(%([data-poetry--core--slider-target="#{name}"])).first["data-slot"].split("-").last
          end)
        end

        def test_a_single_thumb_carries_the_apg_surface_and_one_hidden_input
          fragment = render_slider(value: 25)
          thumbs = fragment.css('[data-slot="slider-thumb"]')

          assert_equal 1, thumbs.size
          thumb = thumbs.first

          assert_equal "slider", thumb["role"]
          assert_equal "0", thumb["tabindex"]
          assert_equal "0", thumb["aria-valuemin"]
          assert_equal "100", thumb["aria-valuemax"]
          assert_equal "25", thumb["aria-valuenow"]
          assert_equal "horizontal", thumb["aria-orientation"]
          assert_equal "Volume", thumb["aria-label"]
          assert_equal "keydown->poetry--core--slider#keydown", thumb["data-action"]
          inputs = fragment.css("input")

          assert_equal 1, inputs.size
          assert_equal "hidden", inputs.first["type"]
          assert_equal "volume", inputs.first["name"], "single mode: bare name"
          assert_equal "25", inputs.first["value"]
        end

        def test_the_server_renders_the_geometry_vars
          root = render_slider(value: 25).css('[data-slot="slider"]').first

          assert_includes root["style"], "--slider-start: 0%"
          assert_includes root["style"], "--slider-end: 25%"
        end

        def test_range_mode_renders_two_thumbs_with_array_params_and_neighbor_clamped_bounds
          fragment = render_slider(values: [200, 800], min: 0, max: 1000, step: 10,
                                   min_steps_between_thumbs: 5,
                                   label: ["Minimum price", "Maximum price"])
          thumbs = fragment.css('[data-slot="slider-thumb"]')

          assert_equal 2, thumbs.size
          assert_equal(%w[0 0], thumbs.map { |thumb| thumb["tabindex"] }, "each thumb is a Tab stop (no roving)")
          assert_equal(["Minimum price", "Maximum price"], thumbs.map { |thumb| thumb["aria-label"] })
          # APG multithumb: DYNAMIC neighbor-clamped bounds (gap = 5 steps
          # x 10 = 50).
          low, high = thumbs

          assert_equal %w[0 750], [low["aria-valuemin"], low["aria-valuemax"]]
          assert_equal %w[250 1000], [high["aria-valuemin"], high["aria-valuemax"]]
          # name[] per input - Rails array params: ["200", "800"].
          inputs = fragment.css("input")

          assert_equal(%w[volume[] volume[]], inputs.map { |input| input["name"] })
          assert_equal(%w[200 800], inputs.map { |input| input["value"] })
          # Geometry spans the two values.
          style = fragment.css('[data-slot="slider"]').first["style"]

          assert_includes style, "--slider-start: 20%"
          assert_includes style, "--slider-end: 80%"
        end

        def test_value_text_renders_aria_valuetext
          thumb = render_slider(value: 40, value_text: ->(value) { "$#{value}" })
                  .css('[data-slot="slider-thumb"]').first

          assert_equal "$40", thumb["aria-valuetext"]
        end

        def test_vertical_orientation_lands_on_every_part
          fragment = render_slider(value: 10, orientation: :vertical)

          %w[slider slider-track slider-range slider-thumb].each do |slot|
            assert_equal "vertical", fragment.css(%([data-slot="#{slot}"])).first["data-orientation"]
          end
          assert_equal "vertical", fragment.css('[data-slot="slider-thumb"]').first["aria-orientation"]
          assert_equal "vertical",
                       fragment.css('[data-slot="slider"]').first["data-poetry--core--slider-orientation-value"]
        end

        def test_disabled_drops_thumbs_from_the_tab_order_but_the_inputs_still_submit
          fragment = render_slider(value: 30, disabled: true)

          assert fragment.css('[data-slot="slider"]').first.key?("data-disabled")
          thumb = fragment.css('[data-slot="slider-thumb"]').first

          assert_equal "-1", thumb["tabindex"]
          assert thumb.key?("data-disabled")
          input = fragment.css("input").first

          refute input.key?("disabled"), "the server value still submits (the control is inert, the datum is not)"
          assert_equal "30", input["value"]
        end

        def test_the_argument_error_contract
          assert_raises(ArgumentError) { Component.new(name: "v", label: "V", value: 1, values: [1, 2]) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: %w[A B], values: [1, 2, 3])) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: %w[A B], values: [80, 20])) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: "V", value: 200)) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: "V", value: 5, step: 0)) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: "V", value: 5, min: 9, max: 1)) }
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: "V", value: "abc")) }
        end

        def test_missing_thumb_names_raise
          error = assert_raises(ArgumentError) { render_inline(Component.new(name: "v", value: 5)) }

          assert_includes error.message, "accessible name"
          assert_raises(ArgumentError) { render_inline(Component.new(name: "v", label: "One", values: [1, 2])) }
        end

        def test_labelled_by_satisfies_the_single_thumb_name
          thumb = render_slider(value: 5, label: nil, labelled_by: "volume-label")
                  .css('[data-slot="slider-thumb"]').first

          assert_equal "volume-label", thumb["aria-labelledby"]
        end

        def test_no_value_defaults_to_one_thumb_at_min
          fragment = render_slider(min: 10)
          thumb = fragment.css('[data-slot="slider-thumb"]').first

          assert_equal 1, fragment.css('[data-slot="slider-thumb"]').size,
                       "poetry diverges from shadcn's [min, max] two-thumb fallback (documented)"
          assert_equal "10", thumb["aria-valuenow"]
        end

        def test_decimal_values_render_without_float_noise
          fragment = render_slider(value: 0.5, min: 0, max: 1, step: 0.1)
          thumb = fragment.css('[data-slot="slider-thumb"]').first

          assert_equal "0.5", thumb["aria-valuenow"]
          assert_equal "0.1", fragment.css('[data-slot="slider"]').first["data-poetry--core--slider-step-value"]
          assert_equal "50%", fragment.css('[data-slot="slider"]').first["style"][/--slider-end: ([\d.]+%)/, 1]
        end

        def test_source_exact_classes_land_on_root_track_range_and_thumb
          fragment = render_slider(value: 25)

          %w[cn-slider relative flex w-full touch-none select-none
             data-[disabled]:opacity-50].each do |token|
            assert_includes fragment.css('[data-slot="slider"]').first["class"], token
          end
          %w[cn-slider-track grow overflow-hidden].each do |token|
            assert_includes fragment.css('[data-slot="slider-track"]').first["class"], token
          end
          assert_includes fragment.css('[data-slot="slider-range"]').first["class"], "cn-slider-range"
          thumb_class = fragment.css('[data-slot="slider-thumb"]').first["class"]

          # The RECORDED focus-ring exception (the source ring-4 swell, not
          # the suite 3px ring) rides .cn-slider-thumb in the theme.
          %w[cn-slider-thumb block shrink-0].each do |token|
            assert_includes thumb_class, token
          end
        end

        def test_described_by_lands_on_each_thumb
          thumbs = render_slider(values: [1, 2], label: %w[Low High], described_by: "hours-hint")
                   .css('[data-slot="slider-thumb"]')

          assert_equal(%w[hours-hint hours-hint], thumbs.map { |thumb| thumb["aria-describedby"] })
        end
      end
    end
  end
end
