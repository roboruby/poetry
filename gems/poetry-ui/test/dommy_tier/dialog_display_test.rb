# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # UA-semantics + JS integration (the bug class that motivated): a
  # closed <dialog> computes display:none from the UA stylesheet alone; the
  # real poetry--core--dialog controller's open() (via the real trigger
  # Button) must clear it. JSDOM-style stacks miss this entirely.
  class DialogDisplayTest < TestCase
    def test_closed_dialog_computes_display_none_until_the_controller_opens_it
      component = Poetry::Ui::Dialog::Component.new
      component.with_trigger { "Open settings" }
      component.with_title { "Settings" }

      harness = render_in_dommy(component, css: false)

      assert_no_js_errors harness

      assert_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display)),
                   "closed <dialog> must compute display:none (UA stylesheet)"

      harness.execute(<<~JS)
        document.querySelector('[data-action*="#open"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump

      assert_no_js_errors harness

      assert_equal "open",
                   harness.evaluate(%(document.querySelector("dialog").dataset.state)),
                   "the dialog controller should stamp data-state=open"
      refute_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display)),
                   "after open() the dialog must no longer compute display:none"
    end
  end
end
