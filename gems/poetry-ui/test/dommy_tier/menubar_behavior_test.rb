# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Menubar markup driven by the REAL poetry--core--menubar
  # coordinator + per-menu poetry--core--menu instances + the bar's
  # horizontal roving focus: ArrowDown on a trigger must open that menu
  # with real focus on its FIRST item; ArrowRight at the menu edge must
  # slide - close File, open Edit, focus Edit's first item, move the bar's
  # single tab stop; Escape must return focus to the owning trigger and
  # null the value. Hover geometry and popper placement stay with the
  # browser pass - dommy has no layout engine.
  class MenubarBehaviorTest < TestCase
    def render_bar
      render_in_dommy(Poetry::Ui::Menubar::Component.new(label: "Application menu")) do |bar|
        bar.with_menu(value: "file") do |menu|
          menu.with_trigger { "File" }
          menu.with_item { "New Tab" }
          menu.with_item { "New Window" }
        end
        bar.with_menu(value: "edit") do |menu|
          menu.with_trigger { "Edit" }
          menu.with_item { "Undo" }
          menu.with_item { "Redo" }
        end
      end
    end

    def bar_state(harness)
      # Contents resolve through each trigger's aria-controls id, never by
      # document order: portal-on-open moves an open menu's content to
      # body, so index pairing stops matching trigger order (the
      # production controllers pair by id for the same reason).
      harness.evaluate(<<~JS)
        (() => {
          const triggers = Array.from(document.querySelectorAll('[data-slot="menubar-trigger"]'));
          const contents = triggers.map((t) => document.getElementById(t.getAttribute("aria-controls")));
          const active = document.activeElement;
          const stateOf = (el) => el.hasAttribute("data-open") ? "open"
            : el.hasAttribute("data-closed") ? "closed" : "none";
          return [
            triggers.map((t) => [t.dataset.value, t.hasAttribute("data-popup-open"),
                                 t.getAttribute("aria-expanded"), t.getAttribute("tabindex")]),
            contents.map((c) => [stateOf(c), c.hidden]),
            document.querySelector('[data-slot="menubar"]')
              .getAttribute("data-poetry--core--menubar-value-value"),
            active ? [active.getAttribute("role"), (active.textContent ?? "").trim()] : null
          ];
        })()
      JS
    end

    def press(harness, key)
      harness.execute(<<~JS)
        document.activeElement.dispatchEvent(
          new KeyboardEvent("keydown", { key: "#{key}", bubbles: true, cancelable: true })
        );
      JS
      harness.pump(rounds: 10)
    end

    def test_keyboard_open_then_arrow_slide_between_menus_then_escape
      harness = render_bar

      assert_no_js_errors harness

      triggers, contents, value, = bar_state(harness)

      assert_equal [["file", false, "false", "0"], ["edit", false, "false", "-1"]], triggers,
                   "server render: closed bar, ONE tab stop on the first trigger"
      assert_equal [%w[closed] << true, %w[closed] << true], contents
      assert_equal "", value

      # ArrowDown on File opens it with real focus on the first item.
      harness.execute(<<~JS)
        const file = document.querySelector('[data-slot="menubar-trigger"]');
        file.focus();
        file.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      triggers, contents, value, active = bar_state(harness)

      assert_equal [["file", true, "true", "0"], ["edit", false, "false", "-1"]], triggers
      assert_equal [%w[open] << false, %w[closed] << true], contents
      assert_equal "file", value
      assert_equal ["menuitem", "New Tab"], active, "keyboard open focuses the FIRST item"

      # ArrowRight at the menu edge slides: File closes, Edit opens, Edit's
      # first item takes focus, the bar tab stop follows.
      press(harness, "ArrowRight")

      assert_no_js_errors harness
      triggers, contents, value, active = bar_state(harness)

      assert_equal [["file", false, "false", "-1"], ["edit", true, "true", "0"]], triggers
      assert_equal [%w[closed] << true, %w[open] << false], contents
      assert_equal "edit", value
      assert_equal %w[menuitem Undo], active, "edge-navigate focuses the destination's FIRST item"

      # ArrowLeft slides back symmetrically.
      press(harness, "ArrowLeft")

      triggers, _contents, value, active = bar_state(harness)

      assert_equal [["file", true, "true", "0"], ["edit", false, "false", "-1"]], triggers
      assert_equal "file", value
      assert_equal ["menuitem", "New Tab"], active

      # Escape closes and returns focus to the OWNING trigger; value nulls.
      press(harness, "Escape")

      assert_no_js_errors harness
      triggers, contents, value, active = bar_state(harness)

      assert_equal [["file", false, "false", "0"], ["edit", false, "false", "-1"]], triggers
      assert_equal [%w[closed] << true, %w[closed] << true], contents
      assert_equal "", value
      assert_equal %w[menuitem File], active, "Escape returns focus to the trigger (bar keeps its tab stop)"
    end
  end
end
