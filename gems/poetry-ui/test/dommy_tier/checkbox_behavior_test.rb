# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Checkbox markup driven by the REAL poetry--core--checked
  # controller: the store inversion end-to-end. A click on the visual
  # button must flip the hidden native input (the store), dispatch a REAL
  # bubbling change event the form can hear (no synthetic prototype-setter
  # dance), and reflect aria-checked + the checked pair (bare data-checked /
  # data-unchecked / data-indeterminate, Base UI vocabulary) on the control
  # AND the indicator. Indeterminate connects via input.indeterminate (a
  # JS-only property derived from the checked attributes) and resolves to
  # CHECKED on the first toggle (Radix-exact).
  class CheckboxBehaviorTest < TestCase
    def render_checkbox(**)
      html = render_inline(Poetry::Ui::Checkbox::Component.new(name: "terms", **)).to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    def checkbox_state(harness)
      # The checked state is a PRESENCE pair (bare data-checked /
      # data-unchecked / data-indeterminate) - derive the key from which
      # attribute is present, asserting exclusivity implicitly.
      harness.evaluate(<<~JS)
        (() => {
          const state = (el) =>
            el.hasAttribute("data-indeterminate") ? "indeterminate" :
            el.hasAttribute("data-checked") ? "checked" :
            el.hasAttribute("data-unchecked") ? "unchecked" : null;
          const control = document.querySelector('[data-slot="checkbox"]');
          const indicator = document.querySelector('[data-slot="checkbox-indicator"]');
          const input = document.querySelector('[data-slot="checkbox-input"]');
          return [control.getAttribute("aria-checked"), state(control),
                  state(indicator), input.checked, input.indeterminate];
        })()
      JS
    end

    def click_control(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="checkbox"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def listen(harness)
      harness.execute(<<~JS)
        window.__events = [];
        document.getElementById("form").addEventListener("change",
          (event) => window.__events.push(["change", event.target.dataset.slot]));
        document.addEventListener("poetry:checkbox:change",
          (event) => window.__events.push(["poetry", event.detail.checked, event.detail.was_indeterminate]));
      JS
    end

    def test_a_real_click_flips_the_native_input_and_the_aria_projection
      harness = render_checkbox

      assert_no_js_errors harness
      assert_equal ["false", "unchecked", "unchecked", false, false], checkbox_state(harness),
                   "server-rendered unchecked"

      listen(harness)
      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["true", "checked", "checked", true, false], checkbox_state(harness),
                   "input first (the store), then aria-checked + the checked pair on control AND indicator"
      # The REAL change event bubbled from the input to the form, plus the
      # component-flavored observe surface.
      assert_equal [%w[change checkbox-input], ["poetry", true, false]],
                   harness.evaluate("window.__events")

      click_control(harness)

      assert_equal ["false", "unchecked", "unchecked", false, false], checkbox_state(harness)
    end

    def test_indeterminate_connects_the_js_only_property_and_resolves_to_checked
      harness = render_checkbox(checked: :indeterminate)

      assert_no_js_errors harness
      # connect() derives input.indeterminate from data-indeterminate (the
      # property has no attribute of its own); input.checked stays false.
      assert_equal ["mixed", "indeterminate", "indeterminate", false, true], checkbox_state(harness)

      listen(harness)
      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["true", "checked", "checked", true, false], checkbox_state(harness),
                   "the first user toggle resolves mixed to CHECKED (Radix-exact)"
      assert_equal [%w[change checkbox-input], ["poetry", true, true]],
                   harness.evaluate("window.__events")
    end

    def test_disabled_control_is_inert
      harness = render_checkbox(disabled: true)

      click_control(harness)

      assert_no_js_errors harness
      assert_equal ["false", "unchecked", "unchecked", false, false], checkbox_state(harness)
    end
  end
end
