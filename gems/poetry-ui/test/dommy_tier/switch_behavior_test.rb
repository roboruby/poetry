# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Switch markup driven by the SAME poetry--core--checked
  # controller Checkbox ships (zero fork - the reuse is the point): a click
  # flips the store input, bubbles a REAL change event (the Turbo
  # auto-submit recipe hangs off it), and reflects aria-checked + the bare
  # data-checked/data-unchecked pair (Base UI vocabulary) on the control
  # AND the thumb. role=switch has no Enter suppression (the controller's
  # guard keys off role=checkbox).
  class SwitchBehaviorTest < TestCase
    def render_switch(**)
      html = render_inline(Poetry::Ui::Switch::Component.new(name: "notifications", **)).to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    def switch_state(harness)
      # The checked state is a PRESENCE pair (bare data-checked /
      # data-unchecked) - derive the key from which attribute is present.
      harness.evaluate(<<~JS)
        (() => {
          const state = (el) =>
            el.hasAttribute("data-checked") ? "checked" :
            el.hasAttribute("data-unchecked") ? "unchecked" : null;
          const control = document.querySelector('[data-slot="switch"]');
          const thumb = document.querySelector('[data-slot="switch-thumb"]');
          const input = document.querySelector('[data-slot="switch-input"]');
          return [control.getAttribute("aria-checked"), state(control),
                  state(thumb), input.checked];
        })()
      JS
    end

    def click_control(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="switch"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_a_real_click_flips_the_store_input_and_slides_the_thumb_state
      harness = render_switch

      assert_no_js_errors harness
      assert_equal ["false", "unchecked", "unchecked", false], switch_state(harness), "server-rendered off"

      harness.execute(<<~JS)
        window.__events = [];
        document.getElementById("form").addEventListener("change",
          (event) => window.__events.push(["change", event.target.dataset.slot]));
        document.addEventListener("poetry:switch:change",
          (event) => window.__events.push(["poetry", event.detail.checked]));
      JS
      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["true", "checked", "checked", true], switch_state(harness),
                   "input first (the store), then aria + the checked pair on control AND thumb"
      # The REAL change event reaches the form (the auto-submit hook) and
      # the prefix derives from data-component - poetry:switch:change, not
      # poetry:checkbox:change, from the UNFORKED shared controller.
      assert_equal [%w[change switch-input], ["poetry", true]], harness.evaluate("window.__events")

      click_control(harness)

      assert_equal ["false", "unchecked", "unchecked", false], switch_state(harness)
    end

    def test_server_rendered_checked_reconciles_and_toggles_off
      harness = render_switch(checked: true)

      assert_no_js_errors harness
      assert_equal ["true", "checked", "checked", true], switch_state(harness),
                   "reconcile-on-connect: the checked pair (server truth) -> input properties"

      click_control(harness)

      assert_equal ["false", "unchecked", "unchecked", false], switch_state(harness)
    end

    def test_disabled_control_is_inert
      harness = render_switch(disabled: true)

      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["false", "unchecked", "unchecked", false], switch_state(harness)
    end
  end
end
