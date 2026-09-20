# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Command markup driven by the REAL poetry--core--command
  # controller: typing must run the deterministic hide-only filter pass
  # (hidden + data-hidden on non-matches, groups/separators derived-hidden,
  # NEVER a reorder), re-seat the highlight twin-write (data-highlighted +
  # the input's aria-activedescendant) on the top-scored match, and land
  # the localized count in the status live region after the 100ms debounce;
  # arrows must move the highlight over visible ∩ enabled items while REAL
  # focus never leaves the input (the activedescendant design - the family
  # delta vs Select's roving focus); Enter must dispatch the cancelable
  # poetry:command:select and do nothing further. Geometry (scrollIntoView
  # positioning) stays with the browser pass - dommy has no layout engine.
  class CommandBehaviorTest < TestCase
    def render_command(**)
      render_in_dommy(Poetry::Ui::Command::Component.new(
                        id: "palette", placeholder: "Type a command...",
                        "aria-label": "Command palette", **
                      )) do |command|
        command.with_group(heading: "Suggestions") do |group|
          group.with_item(value: "calendar", keywords: %w[schedule dates]) { "Calendar" }
          group.with_item(value: "emoji") { "Search Emoji" }
          group.with_item(value: "calculator", disabled: true) { "Calculator" }
        end
        command.with_separator
        command.with_group(heading: "Settings") do |group|
          group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
          group.with_item(value: "billing", shortcut: "⌘B") { "Billing" }
        end
      end
    end

    def type(harness, query)
      harness.execute(<<~JS)
        const input = document.querySelector('[data-slot="command-input"]');
        input.focus();
        input.value = #{query.to_json};
        input.dispatchEvent(new Event("input", { bubbles: true }));
      JS
      # 10 rounds x 16ms clears the 100ms status debounce.
      harness.pump(rounds: 10)
    end

    def keydown(harness, key)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="command-input"]').dispatchEvent(
          new KeyboardEvent("keydown", { key: #{key.to_json}, bubbles: true, cancelable: true })
        );
      JS
      harness.pump(rounds: 10)
    end

    # [data-value, hidden?, data-hidden?] per item, DOM order.
    def item_states(harness)
      harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="command-item"]'))
          .map((item) => [item.dataset.value, item.hasAttribute("hidden"), item.hasAttribute("data-hidden")])
      JS
    end

    # [highlighted data-value, input aria-activedescendant, highlighted id].
    def highlight_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const highlighted = document.querySelector("[data-highlighted]");
          const input = document.querySelector('[data-slot="command-input"]');
          return [highlighted ? highlighted.dataset.value : null,
                  input.getAttribute("aria-activedescendant"),
                  highlighted ? highlighted.id : null];
        })()
      JS
    end

    def status_text(harness)
      harness.evaluate(%(document.querySelector('[data-slot="command-status"]').textContent))
    end

    def test_connect_seats_the_first_enabled_highlight_without_hiding_anything
      harness = render_command

      assert_no_js_errors harness
      value, descendant, id = highlight_state(harness)

      assert_equal "calendar", value
      assert_equal "palette-item-0", id
      assert_equal id, descendant, "the twin-write: data-highlighted + activedescendant together"
      assert_equal [["calendar", false, false], ["emoji", false, false], ["calculator", false, false],
                    ["profile", false, false], ["billing", false, false]], item_states(harness)
    end

    def test_typing_filters_hide_only_and_reseats_the_highlight_and_announces_the_count
      harness = render_command

      harness.execute(<<~JS)
        window.__filters = [];
        document.addEventListener("poetry:command:filter", (event) => {
          window.__filters.push([event.detail.query, event.detail.visible]);
        });
      JS

      type(harness, "bil")

      assert_no_js_errors harness
      assert_equal [["calendar", true, true], ["emoji", true, true], ["calculator", true, true],
                    ["profile", true, true], ["billing", false, false]], item_states(harness),
                   "score-0 items get hidden + data-hidden; the match keeps both off"

      groups_hidden, separator_hidden, empty_hidden = harness.evaluate(<<~JS)
        (() => {
          const groups = Array.from(document.querySelectorAll('[data-slot="command-group"]'));
          return [groups.map((group) => group.hasAttribute("hidden")),
                  document.querySelector('[data-slot="command-separator"]').hasAttribute("hidden"),
                  document.querySelector('[data-slot="command-empty"]').hidden];
        })()
      JS

      assert_equal [true, false], groups_hidden, "a group hides when ALL its items hide"
      assert separator_hidden, "separators hide whenever the query is non-empty (cmdk parity)"
      assert empty_hidden, "one match - the empty part stays hidden"

      value, descendant, id = highlight_state(harness)

      assert_equal "billing", value, "the highlight re-seats on the top-scored visible match"
      assert_equal id, descendant
      assert_equal [["bil", 1]], harness.evaluate("window.__filters")
      assert_equal "1 result", status_text(harness), "the debounced localized count landed"
      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "real focus NEVER leaves the input"

      order = harness.evaluate(<<~JS)
        Array.from(document.querySelectorAll('[data-slot="command-item"]')).map((item) => item.dataset.value)
      JS

      assert_equal %w[calendar emoji calculator profile billing], order,
                   "filtering NEVER reorders the DOM - hide-only"
    end

    def test_keyword_match_and_zero_match_states
      harness = render_command

      type(harness, "sched")

      assert_no_js_errors harness
      assert_equal [["calendar", false, false]],
                   item_states(harness).reject { |(_, hidden, _)| hidden },
                   "data-keywords carry the score-1 band"

      type(harness, "zzz")

      assert_equal 0, harness.evaluate(
        %(document.querySelectorAll('[data-slot="command-item"]:not([hidden])').length)
      )
      refute harness.evaluate(%(document.querySelector('[data-slot="command-empty"]').hidden)),
             "zero matches unhide the empty part"
      assert_equal [nil, nil, nil], highlight_state(harness), "activedescendant clears on zero matches"
      assert_equal "0 results", status_text(harness)

      # Clearing the query restores everything and re-seats the highlight.
      type(harness, "")

      assert_equal(%w[calendar emoji calculator profile billing],
                   item_states(harness).reject { |(_, hidden, _)| hidden }.map(&:first))
      assert_equal "calendar", highlight_state(harness).first
    end

    def test_arrows_walk_visible_enabled_items_with_the_twin_write_and_no_focus_moves
      harness = render_command

      harness.execute(%(document.querySelector('[data-slot="command-input"]').focus();))
      keydown(harness, "ArrowDown")

      assert_no_js_errors harness
      assert_equal "emoji", highlight_state(harness).first

      keydown(harness, "ArrowDown")

      assert_equal "profile", highlight_state(harness).first,
                   "disabled items (calculator) are skipped by the arrows"

      keydown(harness, "ArrowDown")
      keydown(harness, "ArrowDown")

      assert_equal "billing", highlight_state(harness).first, "loop:false stops at the end"

      value, descendant, id = highlight_state(harness)

      assert_equal "palette-item-4", id
      assert_equal id, descendant, "aria-activedescendant tracks every move"
      assert_equal "billing", value
      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "arrows move the activedescendant, never DOM focus"

      keydown(harness, "ArrowUp")

      assert_equal "profile", highlight_state(harness).first
    end

    def test_enter_dispatches_the_cancelable_select_and_does_nothing_further
      harness = render_command

      harness.execute(<<~JS)
        window.__selects = [];
        document.addEventListener("poetry:command:select", (event) => {
          window.__selects.push([event.detail.value, event.detail.label, event.cancelable]);
        });
      JS

      type(harness, "bil")
      keydown(harness, "Enter")

      assert_no_js_errors harness
      assert_equal [["billing", "Billing", true]], harness.evaluate("window.__selects"),
                   "Enter activates the highlighted item; the label excludes the shortcut"
      # No default action: the palette state is untouched (engine, not actor).
      assert_equal "billing", highlight_state(harness).first
      assert_equal "bil",
                   harness.evaluate(%(document.querySelector('[data-slot="command-input"]').value))
      assert_equal "command-input",
                   harness.evaluate("document.activeElement.getAttribute('data-slot')"),
                   "focus stays on the input through activation"
    end

    def test_filter_false_skips_hiding_but_keeps_highlight_and_announcement
      harness = render_command(filter: false)

      type(harness, "zzz")

      assert_no_js_errors harness
      assert_equal(%w[calendar emoji calculator profile billing],
                   item_states(harness).reject { |(_, hidden, _)| hidden }.map(&:first),
                   "server-driven mode: the controller never hides")
      assert_equal "calendar", highlight_state(harness).first
      assert_equal "5 results", status_text(harness), "the count still announces over server results"
    end
  end
end
