# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The Sheet reuses poetry--core--dialog UNCHANGED - this proves the
  # inherited machinery drives the re-skinned markup end to end: the UA
  # keeps the closed <dialog> display:none, the real trigger Button opens
  # it through the controller, and the built-in close button closes it.
  class SheetBehaviorTest < TestCase
    def test_open_and_close_run_through_the_real_dialog_controller
      component = Poetry::Ui::Sheet::Component.new(side: :right)
      component.with_trigger { "Filter results" }
      component.with_title { "Filters" }

      harness = render_in_dommy(component, css: false)

      assert_no_js_errors harness
      assert_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display)),
                   "closed sheet <dialog> must compute display:none (UA stylesheet)"

      harness.execute(<<~JS)
        document.querySelector('[data-action*="#open"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump

      assert_no_js_errors harness
      assert harness.evaluate(%(document.querySelector("dialog").hasAttribute("data-open"))),
             "the shared controller should stamp data-open"
      refute_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display)),
                   "after open() the sheet must no longer compute display:none"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="sheet-close"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump

      assert_no_js_errors harness
      assert harness.evaluate(%(document.querySelector("dialog").hasAttribute("data-closed"))),
             "closing must flip the pair back to data-closed"
      assert_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display)),
                   "the built-in close button must close through the shared controller"
    end
  end
end
