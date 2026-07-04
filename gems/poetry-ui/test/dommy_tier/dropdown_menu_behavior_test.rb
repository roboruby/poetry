# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL DropdownMenu markup driven by the REAL poetry--core--menu
  # controller: a trigger click must unhide the content, flip
  # aria-expanded + the data-open/data-closed pair, write data-open-reason,
  # and token-activate
  # the layer stack (focus-scope + dismissable + roving-focus appended to
  # the content's data-controller); keyboard open (ArrowDown) must land
  # real focus on the first menuitem; activating an item closes the menu
  # (presence exit -> hidden). Geometry (popper placement, hover grace
  # areas) stays with the browser pass - dommy has no layout engine.
  class DropdownMenuBehaviorTest < TestCase
    def render_menu
      render_in_dommy(Poetry::Ui::DropdownMenu::Component.new) do |menu|
        menu.with_trigger(variant: :outline) { "Open" }
        menu.with_item { "Profile" }
        menu.with_item { "Billing" }
      end
    end

    def menu_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="dropdown-menu-trigger"]');
          const content = document.querySelector('[data-slot="dropdown-menu-content"]');
          const state = content.hasAttribute("data-open") ? "open"
            : content.hasAttribute("data-closed") ? "closed" : "none";
          return [trigger.getAttribute("aria-expanded"), state, content.hidden,
                  content.getAttribute("data-open-reason")];
        })()
      JS
    end

    def test_trigger_click_opens_and_activates_the_layer_stack
      harness = render_menu

      assert_no_js_errors harness
      assert_equal ["false", "closed", true, nil], menu_state(harness), "server-rendered closed"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="dropdown-menu-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal ["true", "open", false, "pointer"], menu_state(harness),
                   "click must open with reason: pointer (focus stays off the items)"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="dropdown-menu-content"]').getAttribute("data-controller"))
      )

      # The layer stack is token-ACTIVATED on open, never server-rendered.
      %w[poetry--core--focus-scope poetry--core--dismissable poetry--core--roving-focus].each do |identifier|
        assert_includes controllers, identifier
      end
    end

    def test_keyboard_open_focuses_the_first_item
      harness = render_menu

      harness.execute(<<~JS)
        document.querySelector('[data-slot="dropdown-menu-trigger"]')
          .dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal ["true", "open", false, "keyboard-first"], menu_state(harness)

      focused = harness.evaluate(<<~JS)
        (() => {
          const active = document.activeElement;
          return active ? [active.getAttribute("role"), active.textContent.trim()] : null;
        })()
      JS

      assert_equal %w[menuitem Profile], focused, "keyboard-first must land real focus on the first item"
    end

    def test_item_activation_selects_and_closes
      harness = render_menu

      harness.execute(<<~JS)
        window.__selects = [];
        document.addEventListener("poetry:menu:select", (event) => {
          window.__selects.push(event.detail.value ?? event.target.textContent.trim());
        });
        document.querySelector('[data-slot="dropdown-menu-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
      harness.execute(<<~JS)
        document.querySelectorAll('[data-slot="dropdown-menu-item"]')[0]
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      # The exit rides presence's animationend/timeout fallback -
      # simulated clock, ~0 wall.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["Profile"], harness.evaluate("window.__selects"), "activation dispatches poetry:menu:select"
      assert_equal ["false", "closed", true, nil], menu_state(harness), "select closes the menu"
    end
  end
end
