# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end activation machine: the REAL Tabs markup driven by the REAL
  # poetry--core--tabs + poetry--core--roving-focus pair. The defining tabs
  # move - an arrow key both roves focus AND switches the visible panel
  # (automatic activation) - plus click activation, the Base UI vocabulary
  # flip (data-active / aria-selected / hidden+data-hidden), and disabled
  # triggers staying inert and unreachable.
  class TabsBehaviorTest < TestCase
    def render_tabs
      render_in_dommy(Poetry::Ui::Tabs::Component.new(label: "Settings")) do |tabs|
        tabs.with_tab("Account", value: "account") { "account panel" }
        tabs.with_tab("Password", value: "password") { "password panel" }
        tabs.with_tab("Billing", value: "billing", disabled: true) { "billing panel" }
      end
    end

    def tab_state(harness, value)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="tabs-trigger"][data-value="#{value}"]');
          const panel = document.querySelector('[data-slot="tabs-content"][data-value="#{value}"]');
          return [trigger.hasAttribute("data-active"), trigger.getAttribute("aria-selected"),
                  trigger.getAttribute("tabindex"), panel.hidden, panel.hasAttribute("data-hidden")];
        })()
      JS
    end

    def test_server_rendered_state_survives_connect
      harness = render_tabs

      assert_no_js_errors harness
      assert_equal [true, "true", "0", false, false], tab_state(harness, "account")
      assert_equal [false, "false", "-1", true, true], tab_state(harness, "password")
    end

    def test_click_switches_the_visible_panel
      harness = render_tabs

      harness.execute(<<~JS)
        document.querySelector('[data-slot="tabs-trigger"][data-value="password"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal [true, "true", "0", false, false], tab_state(harness, "password")
      assert_equal [false, "false", "-1", true, true], tab_state(harness, "account")
    end

    def test_an_arrow_key_roves_focus_and_activates_the_tab
      harness = render_tabs

      harness.execute(<<~JS)
        const first = document.querySelector('[data-slot="tabs-trigger"][data-value="account"]');
        first.focus();
        first.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      focused = harness.evaluate("document.activeElement && document.activeElement.dataset.value")

      assert_equal "password", focused, "the arrow roves focus"
      assert_equal [true, "true", "0", false, false], tab_state(harness, "password"),
                   "automatic activation: focus switches the panel"
    end

    def test_a_disabled_tab_is_unreachable_and_inert
      harness = render_tabs

      # Arrow from password (the last enabled tab): loop wraps PAST the
      # disabled billing tab back to account.
      harness.execute(<<~JS)
        const password = document.querySelector('[data-slot="tabs-trigger"][data-value="password"]');
        password.focus();
        password.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        password.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      focused = harness.evaluate("document.activeElement && document.activeElement.dataset.value")

      assert_equal "account", focused, "roving skips the disabled trigger (loop wraps)"
      assert_equal [false, "false", "-1", true, true], tab_state(harness, "billing")

      harness.execute(<<~JS)
        document.querySelector('[data-slot="tabs-trigger"][data-value="billing"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      assert_equal [false, "false", "-1", true, true], tab_state(harness, "billing"), "clicks on disabled are inert"
    end
  end
end
