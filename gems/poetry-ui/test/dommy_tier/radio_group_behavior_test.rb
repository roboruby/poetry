# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL RadioGroup markup driven by the REAL poetry--core--radio-group
  # checked-value machine + poetry--core--roving-focus (default mode,
  # orientation both) on one root. The defining moves: a click checks the
  # HIDDEN NATIVE RADIO (the form participant - native change bubbles to
  # the form), selection FOLLOWS arrow focus (roving entry fires only on
  # keynav, so arrows move-and-check while Tab never checks), re-check
  # no-ops (radios never uncheck), and the roving tab stop rides the
  # checked item.
  class RadioGroupBehaviorTest < TestCase
    def render_group(**options)
      html = render_inline(Poetry::Ui::RadioGroup::Component.new(name: "plan", label: "Plan", **options)) do |group|
        group.with_item(value: "monthly", label: "Monthly")
        group.with_item(value: "yearly", label: "Yearly")
        group.with_item(value: "lifetime", label: "Lifetime")
      end.to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    # [aria-checked, data-state, indicator hidden, input.checked, tabindex]
    # per item value.
    def items_state(harness)
      harness.evaluate(<<~JS)
        (() => Array.from(document.querySelectorAll('[data-slot="radio-group-item"]')).map((item) => [
          item.dataset.value, item.getAttribute("aria-checked"), item.dataset.state,
          item.querySelector('[data-slot="radio-group-indicator"]').hidden,
          item.querySelector('input[type="radio"]').checked,
          item.getAttribute("tabindex")
        ]))()
      JS
    end

    def click_item(harness, value)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="radio-group-item"][data-value="#{value}"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def listen(harness)
      harness.execute(<<~JS)
        window.__events = [];
        document.getElementById("form").addEventListener("change",
          (event) => window.__events.push(["change", event.target.value]));
        document.addEventListener("poetry:radio-group:change",
          (event) => window.__events.push(["poetry", event.detail.value, event.detail.previous]));
      JS
    end

    def test_a_real_click_checks_the_hidden_native_radio_and_the_projection
      harness = render_group(value: "monthly")

      assert_no_js_errors harness
      assert_equal [["monthly", "true", "checked", false, true, "0"],
                    ["yearly", "false", "unchecked", true, false, "-1"],
                    ["lifetime", "false", "unchecked", true, false, "-1"]], items_state(harness),
                   "server-rendered checked state adopted on connect"

      listen(harness)
      click_item(harness, "yearly")

      assert_no_js_errors harness
      # The native radio group re-serializes (siblings uncheck), the aria
      # projection + indicator + tab stop all move together.
      assert_equal [["monthly", "false", "unchecked", true, false, "-1"],
                    ["yearly", "true", "checked", false, true, "0"],
                    ["lifetime", "false", "unchecked", true, false, "-1"]], items_state(harness)
      # poetry event + the REAL native change bubbling from the hidden
      # input to the form (Rails listeners need no shims).
      assert_equal [%w[poetry yearly monthly], %w[change yearly]],
                   harness.evaluate("window.__events")

      click_item(harness, "yearly")

      assert_no_js_errors harness
      assert_equal [%w[poetry yearly monthly], %w[change yearly]],
                   harness.evaluate("window.__events"),
                   "re-check no-ops - radios never uncheck by re-click"
    end

    def test_selection_follows_arrow_focus
      harness = render_group(value: "monthly")

      listen(harness)
      # Arrow from the checked item: roving-focus moves focus AND fires the
      # cancelable entry event; entryCheck makes selection follow focus.
      harness.execute(<<~JS)
        const checked = document.querySelector('[data-slot="radio-group-item"][data-value="monthly"]');
        checked.focus();
        checked.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowDown", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "yearly", harness.evaluate("document.activeElement && document.activeElement.dataset.value"),
                   "the arrow moved focus"
      assert_equal [%w[yearly true], %w[monthly false]],
                   items_state(harness).values_at(1, 0).map { |item| item[0, 2] },
                   "...AND checked (selection follows focus - the APG radio contract)"
      assert harness.evaluate('document.querySelector(\'[data-value="yearly"] input\').checked')

      # ArrowRight also navigates (orientation both: all four arrows).
      harness.execute(<<~JS)
        document.activeElement.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "lifetime", harness.evaluate("document.activeElement && document.activeElement.dataset.value")
      assert_equal "true",
                   harness.evaluate('document.querySelector(\'[data-value="lifetime"]\').getAttribute("aria-checked")')
      assert_equal [%w[poetry yearly monthly], %w[change yearly],
                    %w[poetry lifetime yearly], %w[change lifetime]],
                   harness.evaluate("window.__events")
    end

    def test_disabled_items_are_inert_and_skipped_by_arrows
      harness = render_group(value: "monthly")
      harness.execute(<<~JS)
        const item = document.querySelector('[data-value="yearly"]');
        item.setAttribute("disabled", "");
        item.setAttribute("data-disabled", "");
      JS

      click_item(harness, "yearly")

      assert_no_js_errors harness
      assert_equal "false",
                   harness.evaluate('document.querySelector(\'[data-value="yearly"]\').getAttribute("aria-checked")'),
                   "a disabled item never checks"

      # The arrow collection filters data-disabled at query time: monthly
      # arrows straight to lifetime (and checks it).
      harness.execute(<<~JS)
        const checked = document.querySelector('[data-value="monthly"]');
        checked.focus();
        checked.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowDown", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_equal "lifetime", harness.evaluate("document.activeElement && document.activeElement.dataset.value")
      assert_equal "true",
                   harness.evaluate('document.querySelector(\'[data-value="lifetime"]\').getAttribute("aria-checked")')
    end
  end
end
