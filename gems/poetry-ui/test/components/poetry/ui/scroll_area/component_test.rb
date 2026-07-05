# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module ScrollArea
      class ComponentTest < ViewComponent::TestCase
        def test_the_viewport_is_a_named_focusable_native_scroll_region
          html = render_inline(Component.new(label: "Tags", class: "h-72")) { "rows" }

          viewport = html.css('[data-slot="scroll-area-viewport"]').first

          assert_equal "0", viewport["tabindex"], "a scrollable region a keyboard can't reach fails WCAG"
          assert_equal "region", viewport["role"]
          assert_equal "Tags", viewport["aria-label"]
          assert_includes viewport["class"], "overflow-auto", "NATIVE scrolling - no JS scrollbars"
          assert_includes viewport["class"], "scrollbar-width:thin"
          root = html.css('[data-slot="scroll-area"]').first

          assert_includes root["class"], "h-72", "the caller sizes the box"
        end

        def test_scroll_area_requires_a_label_and_content
          assert_raises(ArgumentError) { render_inline(Component.new) { "rows" } }
          assert_raises(ArgumentError) { render_inline(Component.new(label: "Tags")) }
        end
      end
    end
  end
end
