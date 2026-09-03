# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL ContextMenu markup driven by the REAL poetry--core--context-menu
  # + poetry--core--menu controllers: a contextmenu event at (x, y) must be
  # consumed (preventDefault - the custom menu replaces the native one),
  # write the popper virtual-anchor attribute, open the menu, and
  # token-activate the layer stack; the surface must stay ARIA-free at
  # runtime; disabled must NOT consume the event (native menu passthrough).
  # WHERE the content lands at that point is geometry - dommy has no layout
  # engine, so the at-the-pointer assertion belongs to the browser pass.
  class ContextMenuBehaviorTest < TestCase
    ANCHOR = "data-poetry--core--popper-anchor-point-value"

    def render_menu(**)
      render_in_dommy(Poetry::Ui::ContextMenu::Component.new(**)) do |menu|
        menu.with_trigger(tag: :div) { "Right-click here" }
        menu.with_item { "Rename" }
        menu.with_item { "Duplicate" }
      end
    end

    def menu_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('[data-slot="context-menu"]');
          const trigger = document.querySelector('[data-slot="context-menu-trigger"]');
          const content = document.querySelector('[data-slot="context-menu-content"]');
          const state = content.hasAttribute("data-open") ? "open"
            : content.hasAttribute("data-closed") ? "closed" : "none";
          return [state, content.hidden, root.getAttribute("#{ANCHOR}"),
                  trigger.hasAttribute("aria-expanded"), trigger.hasAttribute("aria-haspopup")];
        })()
      JS
    end

    def test_contextmenu_at_a_point_opens_with_the_anchor_written_and_no_surface_aria
      harness = render_menu

      assert_no_js_errors harness
      assert_equal ["closed", true, nil, false, false], menu_state(harness), "server-rendered closed"

      consumed = harness.evaluate(<<~JS)
        (() => {
          const event = new MouseEvent("contextmenu", {
            bubbles: true, cancelable: true, clientX: 320, clientY: 240
          });
          return !document.querySelector('[data-slot="context-menu-trigger"]').dispatchEvent(event);
        })()
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert consumed, "the contextmenu event must be preventDefault'ed (custom menu replaces native)"
      assert_equal ["open", false, "320,240", false, false], menu_state(harness),
                   "open at the captured point; the surface stays ARIA-free at runtime"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="context-menu-content"]').getAttribute("data-controller"))
      )

      # The layer stack is token-ACTIVATED on open, never server-rendered.
      %w[poetry--core--focus-scope poetry--core--dismissable poetry--core--roving-focus].each do |identifier|
        assert_includes controllers, identifier
      end
    end

    def test_disabled_surface_passes_the_native_menu_through
      harness = render_menu(disabled: true)

      consumed = harness.evaluate(<<~JS)
        (() => {
          const event = new MouseEvent("contextmenu", {
            bubbles: true, cancelable: true, clientX: 100, clientY: 100
          });
          return !document.querySelector('[data-slot="context-menu-trigger"]').dispatchEvent(event);
        })()
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      refute consumed, "disabled must NOT preventDefault - the browser-native menu returns"
      assert_equal ["closed", true, nil, false, false], menu_state(harness)
    end
  end
end
