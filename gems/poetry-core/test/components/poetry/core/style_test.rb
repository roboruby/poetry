# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class StyleTest < Minitest::Test
      # A minimal dictionary standing in for a styled component's sidecar.
      module Glyph
        class Style < Poetry::Core::Style
          base "shrink-0"
          variant :mode, light: "", dark: ""
          variant :color, red: "stroke-red-600/50", blue: "stroke-blue-600/50"
          variant :size, small: "size-3", medium: "size-3.5", large: "size-4"
          variant :shape, square: "", round: ""
        end
      end

      def test_declaring_defaults_in_the_dictionary_raises
        # Single source of truth: defaults live on the component
        # (`style :attr, default:`), never in the style dictionary.
        error = assert_raises(Poetry::Core::Error) do
          Class.new(Poetry::Core::Style) { defaults(color: :red) }
        end

        assert_match(/single source of truth/, error.message)
      end

      def test_variant_options_exposes_the_declared_space
        options = Glyph::Style.variant_options

        assert_equal %i[mode color size shape], options.keys
        assert_equal %i[small medium large], options[:size]
      end

      def test_subclass_extends_a_copy_of_the_parent_dictionary
        subclass = Class.new(Glyph::Style) do
          variant :size, huge: "size-10"
        end

        assert_includes subclass.variant_options[:size], :huge
        refute_includes Glyph::Style.variant_options[:size], :huge
        # And the parent's dictionary still resolves through the subclass.
        assert_includes subclass.css(size: :small), "size-3"
      end

      def test_caller_class_option_wins_conflicts
        css = Glyph::Style.css(size: :small, class: "size-8")

        assert_includes css, "size-8"
        refute_includes css, "size-3"
      end
    end
  end
end
