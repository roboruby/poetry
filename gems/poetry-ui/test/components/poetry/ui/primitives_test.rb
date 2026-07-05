# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # N8 static primitives: Skeleton, Separator, Spinner, Kbd - pure markup,
    # so the contract is the semantic element + the a11y hooks.
    class PrimitivesTest < ViewComponent::TestCase
      # -- Skeleton -----------------------------------------------------------

      def test_skeleton_is_a_sized_pulsing_placeholder
        html = render_inline(Skeleton::Component.new(class: "h-4 w-32")).to_html

        assert_includes html, 'data-slot="skeleton"'
        assert_includes html, "animate-pulse"
        assert_includes html, "w-32" # the caller's size survives the base
      end

      # -- Separator ----------------------------------------------------------

      def test_separator_is_decorative_by_default
        node = render_inline(Separator::Component.new).css('[data-slot="separator"]').first

        assert_equal "true", node["aria-hidden"]
        assert_nil node["role"], "a decorative divider carries no role"
        assert_equal "horizontal", node["data-orientation"]
      end

      def test_a_semantic_separator_wears_the_role_and_orientation
        node = render_inline(Separator::Component.new(decorative: false, orientation: :vertical))
               .css('[data-slot="separator"]').first

        assert_equal "separator", node["role"]
        assert_equal "vertical", node["aria-orientation"]
        assert_nil node["aria-hidden"]
      end

      # -- Spinner ------------------------------------------------------------

      def test_spinner_announces_itself_and_spins
        node = render_inline(Spinner::Component.new).css('[data-slot="spinner"]').first

        assert_equal "svg", node.name, "the spinner IS the glyph, not a wrapper"
        assert_equal "status", node["role"]
        assert_equal "Loading", node["aria-label"]
        assert_includes node["class"], "animate-spin"
      end

      def test_spinner_label_carries_the_loading_context
        node = render_inline(Spinner::Component.new(label: "Saving")).css('[data-slot="spinner"]').first

        assert_equal "Saving", node["aria-label"]
      end

      # -- Kbd ----------------------------------------------------------------

      def test_kbd_is_a_real_kbd_element
        node = render_inline(Kbd::Component.new) { "Esc" }.css("kbd").first

        assert node, "a real <kbd>, not a styled span"
        assert_equal "Esc", node.text
        assert_equal "kbd", node["data-slot"]
      end

      def test_kbd_requires_key_text
        assert_raises(ArgumentError) { render_inline(Kbd::Component.new) }
      end
    end
  end
end
