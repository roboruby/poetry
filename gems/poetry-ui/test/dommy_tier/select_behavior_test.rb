# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Select markup driven by the REAL poetry--core--select
  # controller: a trigger click must unhide the listbox, flip
  # aria-expanded/data-state, token-activate the layer stack, and land
  # real focus on the SELECTED option (every open reason - the Radix
  # parity delta vs the menu family); committing an option must run the
  # native-first sync pipeline (native <select> value + real bubbling
  # change + aria-selected/data-state twins + the value display) and
  # close with focus returned to the trigger; typeahead on the CLOSED
  # trigger must commit without opening (native <select> parity).
  # Geometry (popper placement, scroll-button extremes) stays with the
  # browser pass - dommy has no layout engine.
  class SelectBehaviorTest < TestCase
    def render_select(value: "banana")
      render_in_dommy(Poetry::Ui::Select::Component.new(
                        name: "cart[fruit]", value: value, placeholder: "Select a fruit",
                        "aria-label": "Fruit"
                      )) do |select|
        select.with_item(value: "apple") { "Apple" }
        select.with_item(value: "banana") { "Banana" }
        select.with_item(value: "cherry") { "Cherry" }
      end
    end

    def select_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="select-trigger"]');
          const content = document.querySelector('[data-slot="select-content"]');
          const native = document.querySelector('[data-slot="select-native"]');
          const value = document.querySelector('[data-slot="select-value"]');
          return [trigger.getAttribute("aria-expanded"), content.dataset.state, content.hidden,
                  native.value, value.textContent.trim()];
        })()
      JS
    end

    def open_via_click(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="select-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_click_open_activates_the_layers_and_focuses_the_selected_option
      harness = render_select

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "banana", "Banana"], select_state(harness),
                   "server-rendered closed, the native select already holds the value"

      open_via_click(harness)

      assert_no_js_errors harness
      assert_equal ["true", "open", false, "banana", "Banana"], select_state(harness)

      controllers, reason = harness.evaluate(<<~JS)
        (() => {
          const content = document.querySelector('[data-slot="select-content"]');
          return [content.getAttribute("data-controller"), content.getAttribute("data-open-reason")];
        })()
      JS

      # The layer stack is token-ACTIVATED on open, never server-rendered.
      %w[poetry--core--focus-scope poetry--core--dismissable poetry--core--roving-focus].each do |identifier|
        assert_includes controllers, identifier
      end
      assert_equal "pointer", reason

      focused = harness.evaluate(<<~JS)
        (() => {
          const active = document.activeElement;
          return [active.getAttribute("role"), active.getAttribute("aria-selected"),
                  active.textContent.trim()];
        })()
      JS

      assert_equal %w[option true Banana], focused,
                   "pointer open focuses the SELECTED option (the Radix delta vs the menu family)"
    end

    def test_arrow_plus_enter_commits_through_the_native_first_pipeline
      harness = render_select

      harness.execute(<<~JS)
        window.__events = [];
        document.addEventListener("change", (event) => {
          window.__events.push(["native-change", event.target.value]);
        });
        document.addEventListener("poetry:select:change", (event) => {
          window.__events.push(["poetry-change", event.detail.value, event.detail.previous]);
        });
      JS

      # ArrowDown on the closed trigger opens and focuses the selected option.
      harness.execute(<<~JS)
        const trigger = document.querySelector('[data-slot="select-trigger"]');
        trigger.focus();
        trigger.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "keyboard-selected",
                   harness.evaluate(%(document.querySelector('[data-slot="select-content"]')
                     .getAttribute("data-open-reason")))

      # Arrow to Cherry (roving focus), then Enter commits it.
      %w[ArrowDown Enter].each do |key|
        harness.execute(<<~JS)
          document.activeElement.dispatchEvent(
            new KeyboardEvent("keydown", { key: "#{key}", bubbles: true, cancelable: true })
          );
        JS
        harness.pump(rounds: 10)
      end
      # The close rides presence's animationend/timeout fallback.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "cherry", "Cherry"], select_state(harness),
                   "commit writes the native select AND the display, then closes"
      assert_equal [%w[native-change cherry], %w[poetry-change cherry banana]],
                   harness.evaluate("window.__events"),
                   "a REAL bubbling change fires on the native select (Turbo listeners work unmodified)"

      twins = harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="select-item"]'))
          .map((item) => [item.dataset.value, item.getAttribute("aria-selected"), item.dataset.state])
      JS

      assert_equal [%w[apple false unchecked], %w[banana false unchecked], %w[cherry true checked]], twins,
                   "aria-selected and data-state flip TOGETHER on every option"
      assert_equal "select-trigger",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "focus returns to the trigger after commit"
    end

    def test_typeahead_on_the_closed_trigger_commits_without_opening
      harness = render_select(value: "")

      harness.execute(<<~JS)
        window.__nativeChanges = [];
        document.addEventListener("change", (event) => window.__nativeChanges.push(event.target.value));
        const trigger = document.querySelector('[data-slot="select-trigger"]');
        trigger.focus();
        trigger.dispatchEvent(new KeyboardEvent("keydown", { key: "c", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "cherry", "Cherry"], select_state(harness),
                   "the match commits through the full pipeline WITHOUT opening (native <select> parity)"
      assert_equal ["cherry"], harness.evaluate("window.__nativeChanges")
      refute harness.evaluate(<<~JS), "the placeholder dimming clears once a value lands"
        document.querySelector('[data-slot="select-trigger"]').hasAttribute("data-placeholder")
      JS
    end

    def test_escape_closes_without_committing
      harness = render_select

      open_via_click(harness)
      harness.execute(<<~JS)
        document.activeElement.dispatchEvent(
          new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
        );
      JS
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "banana", "Banana"], select_state(harness),
                   "Esc never commits - the value is untouched"
    end
  end
end
