# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module X
      class ComponentTest < ViewComponent::TestCase
        def test_inherits_from_base_component
          assert_operator Poetry::Core::X::Component, :<, Poetry::Core::Component
        end

        # --- defaults --------------------------------------------------------

        def test_default_style_values
          component = Poetry::Core::X::Component.new

          assert_equal :light, component.mode
          assert_equal :indigo, component.color
          assert_equal :medium, component.size
          assert_equal :square, component.shape
        end

        def test_defaults_are_valid
          assert_predicate Poetry::Core::X::Component.new, :valid?
        end

        def test_variant_getters
          assert_equal %i[light dark], Poetry::Core::X::Component.mode_variants
          assert_equal %i[square round], Poetry::Core::X::Component.shape_variants
          assert_includes Poetry::Core::X::Component.color_variants, :indigo
          assert_includes Poetry::Core::X::Component.size_variants, :medium
        end

        # --- validations -----------------------------------------------------

        def test_rejects_invalid_variant
          component = Poetry::Core::X::Component.new(color: :chartreuse)

          refute_predicate component, :valid?
          assert_predicate component.errors[:color], :any?
        end

        # --- style class resolution (exercises component_module rename) -------

        def test_resolves_its_style_class
          assert_equal Poetry::Core::X::Style, Poetry::Core::X::Component.style_class
          assert_equal Poetry::Core::X::Style, Poetry::Core::X::Component.new.styler
        end

        # --- class_variants CSS pipeline -------------------------------------

        def test_style_css_for_defaults
          css = Poetry::Core::X::Style.css(mode: :light, color: :indigo, size: :medium, shape: :square)

          assert_includes css, "shrink-0"
          assert_includes css, "stroke-indigo-600/50"
          assert_includes css, "size-3.5"
        end

        def test_style_css_dark_mode_compound_variant
          css = Poetry::Core::X::Style.css(mode: :dark, color: :red, size: :small, shape: :square)

          # The dark-mode compound variant overrides the light stroke color.
          assert_includes css, "stroke-red-400"
          assert_includes css, "size-3"
        end

        def test_component_css_delegates_to_style
          css = Poetry::Core::X::Component.new(color: :indigo, size: :medium).css

          assert_includes css, "shrink-0"
          assert_includes css, "stroke-indigo-600/50"
          assert_includes css, "size-3.5"
        end

        # --- rendering -------------------------------------------------------

        def test_renders_an_svg
          render_inline(Poetry::Core::X::Component.new)

          assert_includes rendered_content, "<svg"
          assert_includes rendered_content, "</svg>"
          assert_includes rendered_content, "<path"
          assert_includes rendered_content, 'd="M4 4l6 6m0-6l-6 6"'
        end

        def test_renders_default_svg_attributes
          render_inline(Poetry::Core::X::Component.new)

          assert_includes rendered_content, 'xmlns="http://www.w3.org/2000/svg"'
          assert_includes rendered_content, 'viewbox="0 0 14 14"'
          assert_includes rendered_content, 'data-slot="icon"'
        end

        def test_renders_with_merged_css_class
          render_inline(Poetry::Core::X::Component.new(color: :indigo))

          assert_includes rendered_content, "class="
          assert_includes rendered_content, "shrink-0"
        end
      end
    end
  end
end
