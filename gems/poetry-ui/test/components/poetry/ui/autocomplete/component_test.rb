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
      end
    end
  end
end
