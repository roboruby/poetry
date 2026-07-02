# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The split-brain canary: poetry's dark mode is the CLASS strategy
  # (@custom-variant dark (&:where(.dark, .dark *))). A user whose OS
  # prefers dark but whose page carries no .dark class must get the LIGHT
  # palette everywhere - a component half-following prefers-color-scheme
  # while the tokens follow the class is the split-brain bug. The tinted
  # Bubble is the sharpest probe: its background is relative-color math
  # over --primary (oklch(from var(--primary) L calc(c*0.4) h)), so the
  # computed value proves tokens + arbitrary-value utility + dark variant
  # all resolved together.
  class BubbleDarkModeTest < TestCase
    # Dommy 0.9 substitutes var() in computed values but leaves relative-
    # color math symbolic, so the assertions pin the substituted expression
    # rather than the final color. --primary is achromatic (c = 0), so these
    # ARE oklch(0.93 0 0) and oklch(0.3 0 0) once the math is evaluated -
    # the inner token (20.5% light vs 92.2% dark) plus the outer lightness
    # (.93 vs .3) together prove token cascade AND dark-variant selection.
    # Tighten to the resolved colors if a later dommy evaluates the math.
    LIGHT_TINT = "oklch(from oklch(20.5% 0 0) .93 calc(c * .4) h)"
    DARK_TINT = "oklch(from oklch(92.2% 0 0) .3 calc(c * .4) h)"

    def tinted_bubble
      Poetry::Ui::Bubble::Component.new(variant: :tinted)
    end

    def bubble_background(harness)
      harness.evaluate(<<~JS)
        getComputedStyle(document.querySelector('[data-slot="bubble-content"]')).backgroundColor
      JS
    end

    def test_prefers_dark_without_dark_class_keeps_the_light_value
      harness = render_in_dommy(tinted_bubble, stimulus: false, color_scheme: :dark) { "hello" }

      assert_equal LIGHT_TINT, bubble_background(harness),
                   "prefers-color-scheme: dark alone must NOT flip the class-strategy palette"
    end

    def test_dark_class_on_html_flips_to_the_dark_value
      harness = render_in_dommy(tinted_bubble, stimulus: false, dark: true) { "hello" }

      assert_equal DARK_TINT, bubble_background(harness),
                   ".dark on <html> is the one switch that flips the palette"
    end
  end
end
