# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class StyleTest < Minitest::Test
      def test_declaring_defaults_in_the_dictionary_raises
        # Single source of truth (M2): defaults live on the component
        # (`style :attr, default:`), never in the style dictionary.
        error = assert_raises(Poetry::Core::Error) do
          Class.new(Poetry::Core::Style) { defaults(color: :red) }
        end

        assert_match(/single source of truth/, error.message)
      end

      def test_variant_options_exposes_the_declared_space
        options = Poetry::Core::X::Style.variant_options

        assert_equal %i[mode color size shape], options.keys
        assert_equal %i[small medium large], options[:size]
      end

      def test_subclass_extends_a_copy_of_the_parent_dictionary
        subclass = Class.new(Poetry::Core::X::Style) do
          variant :size, huge: "size-10"
        end

        assert_includes subclass.variant_options[:size], :huge
        refute_includes Poetry::Core::X::Style.variant_options[:size], :huge
        # And the parent's dictionary still resolves through the subclass.
        assert_includes subclass.css(size: :small), "size-3"
      end

      def test_caller_class_option_wins_conflicts
        css = Poetry::Core::X::Style.css(size: :small, class: "size-8")

        assert_includes css, "size-8"
        refute_includes css, "size-3"
      end
    end
  end
end
