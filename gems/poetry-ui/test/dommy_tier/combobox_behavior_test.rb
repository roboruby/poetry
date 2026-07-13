# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Combobox markup driven by the REAL poetry--core--combobox +
  # poetry--core--command controllers composing via the event contract:
  # opening must token-activate focus-scope + dismissable (NEVER
  # roving-focus), land real focus on the COMMAND INPUT (the typing-
  # session call - the delta vs Select's option focus) and seed the
  # highlight on the committed option; a printable key on the CLOSED
  # trigger must open AND seed the filter without committing (Select's
  # typeahead-commit must not leak); Enter must run the native-first
  # commit pipeline (native <select> value + real bubbling change +
  # aria-selected/data-selected twins + the display) and close with focus
  # returned; Esc and Tab must close WITHOUT commit (Popover semantics)
  # and reset the query so reopen starts clean. Geometry (popper
  # placement, anchor-width sizing, scrollIntoView positioning) stays
  # with the browser pass - dommy has no layout engine.
  class ComboboxBehaviorTest < TestCase
    def render_combobox(value: "sveltekit")
      render_in_dommy(Poetry::Ui::Combobox::Component.new(
                        name: "post[framework]", value: value, placeholder: "Select framework...",
                        search_placeholder: "Search framework...", "aria-label": "Framework"
                      )) do |combobox|
        combobox.with_item(value: "next.js") { "Next.js" }
        combobox.with_item(value: "sveltekit") { "SvelteKit" }
        combobox.with_item(value: "nuxt.js") { "Nuxt.js" }
      end
    end

    def combobox_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="combobox-trigger"]');
          const content = document.querySelector('[data-slot="combobox-content"]');
          const native = document.querySelector('[data-slot="combobox-native"]');
          const value = document.querySelector('[data-slot="combobox-value"]');
          const state = content.hasAttribute("data-open") ? "open"
            : content.hasAttribute("data-closed") ? "closed" : "none";
          return [trigger.getAttribute("aria-expanded"), state, content.hidden,
                  native.value, value.textContent.trim()];
        })()
      JS
    end

    def open_via_click(harness)
      # A real pointer press focuses the button before click fires (the
      # focus-scope snapshot the close path restores); dommy's synthetic
      # MouseEvent does not, so mirror the browser explicitly.
      harness.execute(<<~JS)
        const trigger = document.querySelector('[data-slot="combobox-trigger"]');
        trigger.focus();
        trigger.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def keydown_on_active(harness, key)
      harness.execute(<<~JS)
        document.activeElement.dispatchEvent(
          new KeyboardEvent("keydown", { key: #{key.to_json}, bubbles: true, cancelable: true })
        );
      JS
      harness.pump(rounds: 10)
    end

    def input_value(harness)
      harness.evaluate(%(document.querySelector('[data-slot="command-input"]').value))
    end

    def record_events(harness)
      harness.execute(<<~JS)
        window.__events = [];
        document.addEventListener("change", (event) => {
          window.__events.push(["native-change", event.target.value]);
        });
        document.addEventListener("poetry:combobox:change", (event) => {
          window.__events.push(["poetry-change", event.detail.value, event.detail.previous]);
        });
      JS
    end

    def test_click_open_activates_the_layers_and_focuses_the_input_with_the_highlight_seeded
      harness = render_combobox

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "sveltekit", "SvelteKit"], combobox_state(harness),
                   "server-rendered closed, the native select already holds the value"

      open_via_click(harness)

      assert_no_js_errors harness
      assert_equal ["true", "open", false, "sveltekit", "SvelteKit"], combobox_state(harness)

      controllers, reason = harness.evaluate(<<~JS)
        (() => {
          const content = document.querySelector('[data-slot="combobox-content"]');
          return [content.getAttribute("data-controller"), content.getAttribute("data-open-reason")];
        })()
      JS

      # The layer stack is token-ACTIVATED on open - and NEVER includes
      # roving-focus (the popup is Command's activedescendant session).
      %w[poetry--core--focus-scope poetry--core--dismissable].each do |identifier|
        assert_includes controllers, identifier
      end
      refute_includes controllers, "poetry--core--roving-focus",
                      "the family's first popup without roving focus"
      assert_equal "trigger-press", reason

      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "open focuses the INPUT for every reason (a typing session, not a picking session)"

      highlighted_value, descendant, highlighted_id = harness.evaluate(<<~JS)
        (() => {
          const highlighted = document.querySelector("[data-highlighted]");
          const input = document.querySelector('[data-slot="command-input"]');
          return [highlighted ? highlighted.dataset.value : null,
                  input.getAttribute("aria-activedescendant"),
                  highlighted ? highlighted.id : null];
        })()
      JS

      assert_equal "sveltekit", highlighted_value,
                   "the SELECTED option takes the highlight (activedescendant), never DOM focus"
      assert_equal highlighted_id, descendant
    end

    def test_printable_key_on_the_closed_trigger_opens_and_seeds_the_filter_without_committing
      harness = render_combobox(value: "")
      record_events(harness)

      harness.execute(<<~JS)
        const trigger = document.querySelector('[data-slot="combobox-trigger"]');
        trigger.focus();
        trigger.dispatchEvent(new KeyboardEvent("keydown", { key: "v", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "keyboard",
                   harness.evaluate(%(document.querySelector('[data-slot="combobox-content"]')
                     .getAttribute("data-open-reason")))
      assert_equal "v",
                   harness.evaluate(%(document.querySelector('[data-slot="combobox-content"]')
                     .getAttribute("data-open-seed"))),
                   "the typed char rides data-open-seed (poetry extension on the keyboard reason)"
      assert_equal "v", input_value(harness), "the typed char lands in the input - never lost"
      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')")

      visible = harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="command-item"]:not([hidden])'))
          .map((item) => item.dataset.value)
      JS

      assert_equal %w[sveltekit], visible, "the seeded char runs the filter pass immediately"

      expanded, state, _hidden, native_value, = combobox_state(harness)

      assert_equal %w[true open], [expanded, state]
      assert_equal "", native_value, "typing FILTERS, never blind-commits (Select's typeahead-commit does not port)"
      assert_empty harness.evaluate("window.__events"), "no change events - nothing committed"
    end

    def test_enter_commits_through_the_native_first_pipeline_and_returns_focus
      harness = render_combobox
      record_events(harness)

      open_via_click(harness)
      # ArrowDown moves the highlight from the selected option to Nuxt.js.
      keydown_on_active(harness, "ArrowDown")
      keydown_on_active(harness, "Enter")
      # The close rides presence's animationend/timeout fallback.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "nuxt.js", "Nuxt.js"], combobox_state(harness),
                   "commit writes the native select AND the display, then closes"
      assert_equal [%w[native-change nuxt.js], %w[poetry-change nuxt.js sveltekit]],
                   harness.evaluate("window.__events"),
                   "a REAL bubbling change fires on the native select (Turbo listeners work unmodified)"

      twins = harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="command-item"]'))
          .map((item) => [item.dataset.value, item.getAttribute("aria-selected"),
                          item.hasAttribute("data-selected")])
      JS

      assert_equal [["next.js", "false", false], ["sveltekit", "false", false],
                    ["nuxt.js", "true", true]], twins,
                   "aria-selected and data-selected flip TOGETHER on every option " \
                   "(the indicator rides data-selected; unselected = attribute absence)"
      assert_equal "combobox-trigger",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "focus returns to the trigger after commit"
      assert_equal "", input_value(harness), "the query resets on close so reopen starts clean"
    end

    def test_escape_closes_without_committing_and_resets_the_query
      harness = render_combobox
      record_events(harness)

      open_via_click(harness)
      harness.execute(<<~JS)
        const input = document.querySelector('[data-slot="command-input"]');
        input.value = "nux";
        input.dispatchEvent(new Event("input", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
      keydown_on_active(harness, "Escape")
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "sveltekit", "SvelteKit"], combobox_state(harness),
                   "Esc never commits - the value is untouched"
      assert_empty harness.evaluate("window.__events")
      assert_equal "", input_value(harness), "the input resets (the React remount behavior, made explicit)"
      assert_equal "combobox-trigger",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')")
    end

    def test_tab_closes_without_committing_under_popover_semantics
      harness = render_combobox
      record_events(harness)

      open_via_click(harness)
      keydown_on_active(harness, "Tab")
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, "sveltekit", "SvelteKit"], combobox_state(harness),
                   "Tab closes WITHOUT commit (modal: false - the delta vs Select's Tab-inert)"
      assert_empty harness.evaluate("window.__events")
      assert_equal "", input_value(harness)
    end

    # --- multiple (the chips field) ---

    def render_multiple_combobox(values: %w[sveltekit remix])
      render_in_dommy(Poetry::Ui::Combobox::Component.new(
                        name: "post[frameworks]", multiple: true, value: values,
                        placeholder: "Select frameworks...", "aria-label": "Frameworks"
                      )) do |combobox|
        combobox.with_item(value: "next.js") { "Next.js" }
        combobox.with_item(value: "sveltekit") { "SvelteKit" }
        combobox.with_item(value: "nuxt.js") { "Nuxt.js" }
        combobox.with_item(value: "remix") { "Remix" }
      end
    end

    def chip_values(harness)
      harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="combobox-chip"]'))
          .filter((chip) => !chip.closest("template"))
          .map((chip) => chip.dataset.value)
      JS
    end

    def test_multiple_renders_chips_in_value_order_inside_the_toolbar_frame
      harness = render_multiple_combobox

      assert_no_js_errors harness
      assert_equal %w[sveltekit remix], chip_values(harness),
                   "one chip per committed value IN VALUE ORDER"

      role, placeholder, native_name, native_multiple, selected = harness.evaluate(<<~JS)
        (() => {
          const chips = document.querySelector('[data-slot="combobox-chips"]');
          const native = document.querySelector('[data-slot="combobox-native"]');
          return [chips.getAttribute("role"), chips.hasAttribute("data-placeholder"),
                  native.getAttribute("name"), native.multiple,
                  Array.from(native.querySelectorAll("option"))
                    .filter((option) => option.selected).map((option) => option.value)];
        })()
      JS

      assert_equal "toolbar", role, "role=toolbar rides the frame while it holds chips"
      refute placeholder
      assert_equal "post[frameworks][]", native_name, "the [] Rails array convention is derived"
      assert native_multiple, "the native select is the multiple serialization truth"
      assert_equal %w[sveltekit remix], selected
    end

    def test_multiple_toggle_commits_without_closing_the_popup
      harness = render_multiple_combobox
      record_events(harness)

      # Mousedown anywhere in the chips frame focuses the input and opens.
      harness.execute(<<~JS)
        const chips = document.querySelector('[data-slot="combobox-chips"]');
        chips.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "a chips-area press focuses the INLINE input"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="command-item"][data-value="next.js"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal %w[sveltekit remix next.js], chip_values(harness),
                   "selection TOGGLES - appended at the value-order end"

      state, hidden = harness.evaluate(<<~JS)
        (() => {
          const content = document.querySelector('[data-slot="combobox-content"]');
          return [content.hasAttribute("data-open") ? "open" : "closed", content.hidden];
        })()
      JS

      assert_equal ["open", false], [state, hidden], "the popup STAYS OPEN on select (Base UI multiple)"
      assert_equal %w[native-change poetry-change],
                   harness.evaluate("window.__events.map((entry) => entry[0])"),
                   "a REAL bubbling change fires on the native select FIRST, then poetry:combobox:change"
    end
  end
end
