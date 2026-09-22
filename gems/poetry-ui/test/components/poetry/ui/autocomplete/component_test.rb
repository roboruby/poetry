# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Autocomplete
      class ComponentTest < ViewComponent::TestCase
        def render_autocomplete(**)
          html = render_inline(Component.new(name: "tag", label: "Tags", **)) do |auto|
            auto.with_item(label: "feature")
            auto.with_item(label: "fix")
          end
          Nokogiri::HTML5.fragment(html.to_html)
        end

        # The popup used to ride the popper's zero default and sit flush
        # against the input; every sibling popup opens with a gap.
        def test_the_suggestion_popup_opens_four_pixels_below_the_input_like_combobox
          root = render_autocomplete.at_css('[data-component="autocomplete"]')

          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
        end

        def test_side_offset_sets_the_gap
          root = render_autocomplete(side_offset: 8).at_css('[data-component="autocomplete"]')

          assert_equal "8", root["data-poetry--core--popper-side-offset-value"]
        end

        def test_the_given_id_lands_on_the_input_and_the_other_ids_derive_from_it
          fragment = render_autocomplete(id: "city", "aria-describedby": "city-hint", aria: { invalid: true })
          input = fragment.at_css("input")
          root = fragment.at_css('[data-component="autocomplete"]')

          assert_equal "city", input["id"], "the Field label's for= target is the real control"
          assert_equal "city-root", root["id"]
          assert_equal "city-list", fragment.at_css('[role="listbox"]')["id"]
          assert_equal "city-list", input["aria-controls"]
          assert_equal "city-item-0", fragment.at_css('[role="option"]')["id"]
          assert_equal "city-hint", input["aria-describedby"], "flat aria-* moves to the input"
          assert_equal "true", input["aria-invalid"], "nested aria: {} moves to the input"
          assert_nil root["aria-describedby"]
          assert_nil root["aria-invalid"]
        end

        def test_without_an_id_the_input_gets_a_stable_instance_id
          input = render_autocomplete.at_css("input")

          assert_match(/\Apoetry-autocomplete-/, input["id"])
          assert_equal "#{input["id"]}-list", input["aria-controls"]
        end
      end
    end
  end
end
