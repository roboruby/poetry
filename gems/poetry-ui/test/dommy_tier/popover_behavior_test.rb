# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Popover markup driven by the REAL poetry--core--popover
  # controller: a trigger click must unhide the role=dialog content, flip
  # aria-expanded + the state attributes on BOTH trigger (data-popup-open)
  # and content (data-open/data-closed), and token-activate
  # the layer stack (focus-scope + dismissable appended to the content's
  # data-controller with trapped/scrim values = modal); focus must move to
  # the first tabbable (the dialog pattern - focus-scope's mount default,
  # not vetoed); Esc must close through the dismissable layer and return
  # focus to the trigger. Geometry (popper placement) stays with the
  # browser pass - dommy has no layout engine.
  class PopoverBehaviorTest < TestCase
    def render_popover(**)
      component = Poetry::Ui::Popover::Component.new(**)
      component.with_trigger(variant: :outline) { "Open popover" }
      component.with_title { "Dimensions" }
      component.with_content('<input type="text" name="width" value="100%">'.html_safe)
      render_in_dommy(component)
    end

    def popover_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="popover-trigger"]');
          const content = document.querySelector('[data-slot="popover-content"]');
          const contentState = content.hasAttribute("data-open") ? "open"
            : content.hasAttribute("data-closed") ? "closed" : "none";
          return [trigger.getAttribute("aria-expanded"), trigger.hasAttribute("data-popup-open"),
                  contentState, content.hidden];
        })()
      JS
    end

    def open_via_click(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="popover-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_trigger_click_opens_and_token_activates_the_layer_stack
      harness = render_popover

      assert_no_js_errors harness
      assert_equal ["false", false, "closed", true], popover_state(harness), "server-rendered closed"

      open_via_click(harness)

      assert_no_js_errors harness
      assert_equal ["true", true, "open", false], popover_state(harness)

      content_attrs = harness.evaluate(<<~JS)
        (() => {
          const content = document.querySelector('[data-slot="popover-content"]');
          return [content.getAttribute("data-controller"),
                  content.getAttribute("data-poetry--core--focus-scope-trapped-value"),
                  content.getAttribute("data-poetry--core--dismissable-disable-outside-pointer-events-value")];
        })()
      JS

      # The layer stack is token-ACTIVATED on open, never server-rendered;
      # non-modal = untrapped scope + no pointer-events scrim (Radix parity).
      %w[poetry--core--focus-scope poetry--core--dismissable].each do |identifier|
        assert_includes content_attrs[0], identifier
      end
      assert_equal %w[false false], content_attrs[1..]
    end

    def test_open_moves_focus_to_the_first_tabbable
      harness = render_popover

      open_via_click(harness)

      assert_no_js_errors harness
      focused = harness.evaluate(<<~JS)
        (() => {
          const active = document.activeElement;
          return active ? [active.tagName.toLowerCase(), active.getAttribute("name")] : null;
        })()
      JS

      assert_equal %w[input width], focused, "the dialog pattern: focus moves IN on open (first tabbable)"
    end

    def test_escape_closes_through_the_dismissable_layer_and_removes_the_tokens
      harness = render_popover

      open_via_click(harness)
      harness.execute(<<~JS)
        document.activeElement.dispatchEvent(
          new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
      JS
      # The exit rides presence's animationend/timeout fallback.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", false, "closed", true], popover_state(harness), "Esc closes"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="popover-content"]').getAttribute("data-controller"))
      )

      refute_includes controllers.to_s, "poetry--core--focus-scope", "layer tokens removed after presence"
      refute_includes controllers.to_s, "poetry--core--dismissable"
    end
  end
end
