# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The purged-CSS canary (the browser pass caught sr-only/animate-spin
  # vanishing from host builds, 2026-07-01): the compiled Tailwind build
  # this tier loads is the same recipe as css:verify_compiled, and a
  # default Button's computed background must be the --primary token - if
  # the dictionary classes were purged (or the safelist drifted), the
  # background falls back to the initial transparent value.
  class ButtonCssTest < TestCase
    INITIAL_BACKGROUNDS = ["", "transparent", "rgba(0, 0, 0, 0)"].freeze

    def test_default_button_background_is_styled_by_the_compiled_build
      harness = render_in_dommy(Poetry::Ui::Button::Component.new, stimulus: false) { "Save" }
      background = harness.evaluate(%(getComputedStyle(document.querySelector("button")).backgroundColor))

      refute_includes INITIAL_BACKGROUNDS, background,
                      "bg-primary was purged from the compiled build (background computes initial)"
      # Lightning CSS serializes the token's oklch(0.205 0 0) as a percent.
      assert_equal "oklch(20.5% 0 0)", background,
                   "a default Button's background must be the --primary token"
    end
  end
end
