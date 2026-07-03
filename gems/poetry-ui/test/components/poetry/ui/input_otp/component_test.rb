# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module InputOtp
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_otp(**)
          doc(render_inline(Component.new(name: "code", length: 6, **)).to_html)
        end

        def test_the_single_input_architecture_renders
          fragment = render_otp
          root = fragment.css('[data-slot="input-otp-container"]').first
          input = fragment.css("input").first

          assert_equal "input_otp", root["data-component"]
          assert_equal "poetry--core--otp", root["data-controller"]
          assert_equal "6", root["data-poetry--core--otp-length-value"]
          assert_equal "\\d", root["data-poetry--core--otp-pattern-value"]
          assert_equal "click->poetry--core--otp#focusInput", root["data-action"]
          assert_equal "ltr", root["dir"], "codes are LTR strings - slot order == string order on RTL pages"
          # THE control: exactly one input, native everything.
          assert_equal 1, fragment.css("input").size
          assert_equal "input-otp", input["data-slot"]
          assert_equal "text", input["type"]
          assert_equal "code", input["name"]
          assert_equal "6", input["maxlength"]
          assert_equal "[0-9]{6}", input["pattern"]
          assert_equal "numeric", input["inputmode"], ":digits -> the SMS keypad"
          assert_equal "one-time-code", input["autocomplete"], "the SMS-autofill contract (load-bearing)"
          assert_equal "false", input["spellcheck"]
          assert_equal "off", input["autocapitalize"]
          assert_equal "off", input["autocorrect"]
          assert_equal "input->poetry--core--otp#sync focus->poetry--core--otp#sync " \
                       "blur->poetry--core--otp#sync paste->poetry--core--otp#paste",
                       input["data-action"]
        end

        def test_exactly_one_focusable_element_and_an_aria_hidden_visual_layer
          fragment = render_otp(groups: [3, 3])
          input = fragment.css("input").first

          # The input hides via opacity, NEVER sr-only/display:none - it
          # must stay clickable + focusable + AT-visible.
          assert_includes input["class"], "opacity-[0.005]"
          assert_includes input["class"], "absolute"
          refute_includes input["class"], "sr-only"
          refute input.key?("tabindex"), "the input IS the (only) Tab stop"
          assert_nil input["aria-hidden"]
          # Everything visual is aria-hidden.
          assert_equal(%w[true true], fragment.css('[data-slot="input-otp-group"]').map do |group|
            group["aria-hidden"]
          end)
          separator = fragment.css('[data-slot="input-otp-separator"]').first

          assert_equal "separator", separator["role"]
          assert_equal "true", separator["aria-hidden"],
                       "aria-hidden DESPITE the source's bare role=separator (recorded divergence)"
          assert(fragment.css('[data-slot="input-otp-slot"]').none? { |slot| slot["tabindex"] })
        end

        def test_slot_count_equals_length_and_groups_cluster_with_separators
          fragment = render_otp(groups: [2, 2, 2])

          assert_equal 6, fragment.css('[data-slot="input-otp-slot"]').size
          assert_equal 3, fragment.css('[data-slot="input-otp-group"]').size
          assert_equal 2, fragment.css('[data-slot="input-otp-separator"]').size, "separators BETWEEN groups only"
          assert_equal 0, render_otp.css('[data-slot="input-otp-separator"]').size, "one group - no separator"
        end

        def test_separator_false_suppresses_the_dash
          assert_equal 0, render_otp(groups: [3, 3], separator: false)
            .css('[data-slot="input-otp-separator"]').size
        end

        def test_the_server_paints_the_value_into_the_input_and_the_cells
          fragment = render_otp(value: "12")
          input = fragment.css("input").first
          slots = fragment.css('[data-slot="input-otp-slot"]')

          assert_equal "12", input["value"]
          assert_equal(["1", "2", "", "", "", ""], slots.map { |slot| slot.children.first&.text.to_s.strip })
          # The caret element ships hidden (the controller reveals it on
          # the active EMPTY cell only).
          assert(slots.all? { |slot| slot.css("[data-otp-caret]").first.key?("hidden") })
        end

        def test_a_long_value_truncates_to_length
          assert_equal "123456", render_otp(value: "1234567890").css("input").first["value"]
        end

        def test_pattern_alphanumeric_and_custom_regexp
          fragment = render_otp(pattern: :alphanumeric)
          input = fragment.css("input").first

          assert_equal "[a-zA-Z0-9]{6}", input["pattern"]
          assert_equal "text", input["inputmode"]
          assert_equal "[a-zA-Z0-9]",
                       fragment.css('[data-slot="input-otp-container"]').first["data-poetry--core--otp-pattern-value"]

          custom = render_otp(pattern: /[0-7]/)

          assert_equal "(?:[0-7]){6}", custom.css("input").first["pattern"]
          assert_equal "[0-7]",
                       custom.css('[data-slot="input-otp-container"]').first["data-poetry--core--otp-pattern-value"]
        end

        def test_the_argument_error_contract
          assert_raises(ArgumentError) { Component.new(name: "code", length: 0) }
          assert_raises(ArgumentError) { Component.new(name: "code", length: 13) }
          assert_raises(ArgumentError) { Component.new(name: "code", length: 6, groups: [3, 2]) }
          assert_raises(ArgumentError) { Component.new(name: "code", length: 6, groups: %w[a b]) }
          assert_raises(ArgumentError) { Component.new(name: "code", length: 6, pattern: "^[a-z]+$") }
        end

        def test_disabled_lands_on_the_input_and_dims_via_css_has
          fragment = render_otp(disabled: true)

          assert fragment.css("input").first.key?("disabled")
          # No data-disabled needed: the container dims via has-disabled:
          # (pure CSS :has - source-exact).
          assert_includes fragment.css('[data-slot="input-otp-container"]').first["class"], "has-disabled:opacity-50"
        end

        def test_required_is_aria_only_and_invalid_marks_input_and_cells
          fragment = render_otp(required: true, invalid: true)
          input = fragment.css("input").first

          assert_equal "true", input["aria-required"]
          refute input.key?("required"), "never native required (the /Field rule)"
          assert_equal "true", input["aria-invalid"]
          assert(fragment.css('[data-slot="input-otp-slot"]').all? { |slot| slot["aria-invalid"] == "true" },
                 "cells carry the styling hook (aria-hidden - AT never hears it)")
        end

        def test_field_control_attributes_land_on_the_input_not_the_container
          field = Field::Component.new(id: "verify-code", label_text: "Verification code",
                                       hint: "6-digit code", error: "is invalid")
          fragment = doc(render_inline(Component.new(name: "code", length: 6,
                                                     **field.control_attributes.transform_keys(&:to_sym))).to_html)
          input = fragment.css("input").first

          assert_equal "verify-code", input["id"], "the label-for target is the REAL control"
          assert_equal "verify-code-error verify-code-hint", input["aria-describedby"]
          assert_equal "true", input["aria-invalid"]
          root = fragment.css('[data-slot="input-otp-container"]').first

          assert_nil root["aria-describedby"], "input-facing attributes never leak onto the container"
        end

        def test_source_exact_classes_land_on_container_slot_and_caret
          fragment = render_otp(groups: [3, 3], value: "1")

          %w[flex items-center gap-2 has-disabled:opacity-50].each do |token|
            assert_includes fragment.css('[data-slot="input-otp-container"]').first["class"], token
          end
          slot_class = fragment.css('[data-slot="input-otp-slot"]').first["class"]

          %w[h-9 w-9 border-y border-r border-input first:rounded-l-md first:border-l last:rounded-r-md
             data-[active=true]:border-ring data-[active=true]:ring-[3px] data-[active=true]:ring-ring/50
             aria-invalid:border-destructive dark:bg-input/30].each do |token|
            assert_includes slot_class, token
          end
          caret_bar = fragment.css("[data-otp-caret] div").first

          %w[h-4 w-px animate-caret-blink bg-foreground duration-1000].each do |token|
            assert_includes caret_bar["class"], token
          end
        end

        def test_caller_classes_style_the_container
          root = render_otp(class: "justify-center").css('[data-slot="input-otp-container"]').first

          assert_includes root["class"], "justify-center"
        end
      end
    end
  end
end
