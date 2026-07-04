# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Toggle markup driven by the REAL poetry--core--pressed
  # micro-controller: a click flips aria-pressed AND the bare data-pressed
  # presence boolean together (never separately - the pressed accent styling
  # is pure CSS off data-pressed; unpressed = attribute absent), and
  # poetry:toggle:change is CANCELABLE - preventDefault vetoes the flip
  # before it renders (the confirm-first host recipe).
  class ToggleBehaviorTest < TestCase
    def render_toggle(**, &block)
      block ||= proc { "Italic" }
      render_in_dommy(Poetry::Ui::Toggle::Component.new(**), &block)
    end

    def toggle_state(harness)
      # [aria-pressed, data-pressed PRESENCE] - unpressed is attribute
      # absence (Base UI presence boolean), so the check is hasAttribute.
      harness.evaluate(<<~JS)
        (() => {
          const control = document.querySelector('[data-slot="toggle"]');
          return [control.getAttribute("aria-pressed"), control.hasAttribute("data-pressed")];
        })()
      JS
    end

    def click_control(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="toggle"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_a_real_click_flips_aria_pressed_and_data_pressed_together
      harness = render_toggle

      assert_no_js_errors harness
      assert_equal ["false", false], toggle_state(harness), "server-rendered unpressed (no data-pressed)"

      harness.execute(<<~JS)
        window.__events = [];
        document.addEventListener("poetry:toggle:change",
          (event) => window.__events.push(event.detail.pressed));
      JS
      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["true", true], toggle_state(harness)
      assert_equal [true], harness.evaluate("window.__events"),
                   "the detail carries the state the toggle is ABOUT to enter"

      click_control(harness)

      assert_equal ["false", false], toggle_state(harness)
    end

    def test_the_change_event_is_cancelable_before_the_flip_renders
      harness = render_toggle

      harness.execute(<<~JS)
        document.addEventListener("poetry:toggle:change", (event) => event.preventDefault());
      JS
      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["false", false], toggle_state(harness), "a vetoed flip never reaches the DOM"
    end

    def test_disabled_toggle_is_inert
      harness = render_toggle(disabled: true, pressed: true)

      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["true", true], toggle_state(harness), "server-rendered pressed stands; no flip"
    end
  end
end
