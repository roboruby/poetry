# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      # The BEM token IR + css_mode emission (U2).
      class BemTest < ViewComponent::TestCase
        # A minimal styled component exercising symbol AND boolean modifiers.
        module Chip
          class Component < Poetry::Core::Component
            style :color, default: :gray, variants: %i[gray red]
            style :outlined, variants: :boolean, default: false

            def call
              content_tag(:span, "chip", class: css)
            end
          end

          class Style < Poetry::Core::Style
            base "inline-flex rounded"
            element :icon, "size-3"
            variant :color, gray: "bg-muted text-muted-foreground", red: "bg-destructive/15 text-destructive"
            variant :outlined, { true => "border border-border", false => "" }
          end
        end

        def teardown
          Poetry::Core::Config.current.css_mode = :tailwind
        end

        def test_bem_block_derives_from_component_path
          assert_equal "poetry-core-x", Poetry::Core::X::Component.new.bem_block
        end

        def test_bem_emits_block_plus_value_modifiers
          bem = Poetry::Core::X::Component.new(color: :red, size: :small).bem

          assert_includes bem, "poetry-core-x"
          assert_includes bem, "poetry-core-x--color-red"
          assert_includes bem, "poetry-core-x--size-small"
          assert_includes bem, "poetry-core-x--mode-light" # default value still names its modifier
        end

        def test_boolean_styles_are_presence_modifiers
          chip = Chip::Component.new(outlined: true)

          assert_includes chip.bem, "--outlined"
          refute_includes Chip::Component.new(outlined: false).bem, "--outlined"
        end

        def test_bem_element
          assert_equal "poetry-core-x__icon", Poetry::Core::X::Component.new.bem(:icon)
        end

        def test_css_mode_tailwind_is_the_default
          assert_equal :tailwind, Poetry::Core::Config.current.css_mode
          assert_includes Chip::Component.new.css, "bg-muted"
        end

        def test_css_mode_bem_per_call_override
          css = Chip::Component.new(color: :red).css(css_mode: :bem)

          assert_includes css, "--color-red"
          refute_includes css, "bg-destructive/15"
        end

        def test_css_mode_bem_appends_caller_classes_verbatim
          css = Chip::Component.new.css(css_mode: :bem, class: "my-custom")

          assert css.end_with?("my-custom")
        end

        def test_unknown_css_mode_raises
          assert_raises(Poetry::Core::Error) { Chip::Component.new.css(css_mode: :both) }
        end

        # The M2 DoD: the same component renders under BOTH modes via the
        # global config switch.
        def test_component_renders_in_both_modes
          Poetry::Core::Config.current.css_mode = :tailwind
          tailwind_html = render_inline(Chip::Component.new(color: :red)).to_html

          assert_includes tailwind_html, "text-destructive"
          refute_includes tailwind_html, "--color-red"

          Poetry::Core::Config.current.css_mode = :bem
          bem_html = render_inline(Chip::Component.new(color: :red)).to_html

          assert_includes bem_html, "--color-red"
          refute_includes bem_html, "text-destructive"
        end
      end
    end
  end
end
