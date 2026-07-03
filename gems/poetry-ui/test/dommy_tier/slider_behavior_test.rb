# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Slider markup driven by the REAL poetry--core--slider math
  # core. The keyboard path end-to-end: arrows step aria-valuenow AND the
  # hidden input by exactly one step (large steps x10 via Shift/PageUp,
  # Home/End hit the effective bounds), each keydown commits (native
  # input/change bubble to the form - Radix onValueCommit parity), the
  # geometry vars re-project, and range thumbs clamp at the neighbor's
  # gap with their aria bounds rewritten cross-thumb. Pointer math needs a
  # layout engine - that stays in the browser pass, by design.
  class SliderBehaviorTest < TestCase
    def render_slider(**)
      html = render_inline(
        Poetry::Ui::Slider::Component.new(name: "volume", label: "Volume", **)
      ).to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    def key(harness, key, index: 0, shift: false)
      harness.execute(<<~JS)
        document.querySelectorAll('[data-slot="slider-thumb"]')[#{index}]
          .dispatchEvent(new KeyboardEvent("keydown",
            { key: "#{key}", shiftKey: #{shift}, bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)
    end

    # [aria-valuemin, aria-valuenow, aria-valuemax] per thumb + input values.
    def state(harness)
      harness.evaluate(<<~JS)
        (() => [
          Array.from(document.querySelectorAll('[data-slot="slider-thumb"]')).map((thumb) => [
            thumb.getAttribute("aria-valuemin"), thumb.getAttribute("aria-valuenow"),
            thumb.getAttribute("aria-valuemax")
          ]),
          Array.from(document.querySelectorAll('input[type="hidden"]')).map((input) => input.value)
        ])()
      JS
    end

    def test_arrow_steps_move_aria_valuenow_the_hidden_input_and_the_geometry
      harness = render_slider(value: 50)

      assert_no_js_errors harness
      assert_equal [[%w[0 50 100]], ["50"]], state(harness), "server truth adopted on connect"

      harness.execute(<<~JS)
        window.__events = [];
        document.addEventListener("poetry:slider:change", (e) => window.__events.push(["change", e.detail.value]));
        document.addEventListener("poetry:slider:commit", (e) => window.__events.push(["commit", e.detail.value]));
        document.getElementById("form").addEventListener("change", (e) => window.__events.push(["native", e.target.value]));
      JS
      key(harness, "ArrowRight")

      assert_no_js_errors harness
      assert_equal [[%w[0 51 100]], ["51"]], state(harness),
                   "one step: aria-valuenow AND the hidden input move together"
      assert_equal "51%", harness.evaluate(
        'document.querySelector(\'[data-slot="slider"]\').style.getPropertyValue("--slider-end").trim()'
      ), "the geometry var re-projects"
      # change per mutation + commit per keydown + the REAL native change.
      assert_equal [["change", [51]], %w[native 51], ["commit", [51]]],
                   harness.evaluate("window.__events")

      key(harness, "ArrowDown")

      assert_equal [[%w[0 50 100]], ["50"]], state(harness), "ArrowDown decrements"

      key(harness, "ArrowUp", shift: true)

      assert_equal [[%w[0 60 100]], ["60"]], state(harness), "Shift+Arrow = the x10 large step"

      key(harness, "PageDown")

      assert_equal [[%w[0 50 100]], ["50"]], state(harness), "PageDown = -10"

      key(harness, "End")

      assert_equal [[%w[0 100 100]], ["100"]], state(harness)

      key(harness, "ArrowRight")

      assert_equal [[%w[0 100 100]], ["100"]], state(harness), "clamped at max - no event storm"

      key(harness, "Home")

      assert_equal [[%w[0 0 100]], ["0"]], state(harness)
    end

    def test_range_thumbs_clamp_at_the_gap_and_rewrite_each_others_bounds
      harness = render_slider(values: [40, 60], min_steps_between_thumbs: 5,
                              label: %w[Low High])

      assert_no_js_errors harness
      assert_equal [[%w[0 40 55], %w[45 60 100]], %w[40 60]], state(harness),
                   "server-rendered neighbor-clamped bounds"

      # End on the LOW thumb clamps at high - gap, never crossing.
      key(harness, "End", index: 0)

      assert_no_js_errors harness
      assert_equal [[%w[0 55 55], %w[60 60 100]], %w[55 60]], state(harness),
                   "the low thumb stops at high - gap AND the high thumb's aria-valuemin was rewritten"

      # The high thumb's Home clamps symmetrically.
      key(harness, "Home", index: 1)

      assert_equal [[%w[0 55 55], %w[60 60 100]], %w[55 60]], state(harness),
                   "already pinned at the gap - no movement"
    end

    def test_decimal_steps_land_on_the_exact_grid
      harness = render_slider(value: 0.2, min: 0, max: 1, step: 0.1)

      key(harness, "ArrowRight")

      assert_no_js_errors harness
      assert_equal "0.3", harness.evaluate(
        'document.querySelector(\'[data-slot="slider-thumb"]\').getAttribute("aria-valuenow")'
      ), "0.1 grids land on 0.3, never 0.30000000000000004 (the precision core)"
    end

    def test_disabled_sliders_ignore_the_keyboard
      harness = render_slider(value: 50, disabled: true)

      key(harness, "ArrowRight")

      assert_no_js_errors harness
      assert_equal [[%w[0 50 100]], ["50"]], state(harness)
    end
  end
end
