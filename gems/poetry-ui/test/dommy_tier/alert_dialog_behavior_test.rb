# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The AlertDialog posture through the REAL shared controller: backdrop
  # clicks must NOT dismiss (dismissible-value=false short-circuits
  # backdropClose), while Esc - the native cancel event - still closes
  # (close() deliberately ignores dismissibleValue). That asymmetry is
  # Radix AlertDialog's exact behavior; this test keeps anyone from
  # "fixing" it.
  class AlertDialogBehaviorTest < TestCase
    def test_backdrop_click_does_not_close_but_esc_does
      component = Poetry::Ui::AlertDialog::Component.new
      component.with_trigger { "Delete account" }
      component.with_title { "Are you absolutely sure?" }
      component.with_description { "This cannot be undone." }
      component.with_cancel { "Cancel" }
      component.with_action(variant: :destructive) { "Delete" }
      component.with_content("")

      harness = render_in_dommy(component, css: false)

      harness.execute(<<~JS)
        document.querySelector('[data-action*="#open"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump

      assert_no_js_errors harness
      assert harness.evaluate(%(document.querySelector("dialog").hasAttribute("data-open"))),
             "the shared controller should stamp data-open"

      # A backdrop click targets the <dialog> element itself at coordinates
      # outside its rect - the exact path backdropClose dismisses a Dialog
      # through. Here dismissible-value=false must no-op it.
      harness.execute(<<~JS)
        document.querySelector("dialog")
          .dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: 4000, clientY: 4000 }));
      JS
      harness.pump

      assert_no_js_errors harness
      assert harness.evaluate(%(document.querySelector("dialog").hasAttribute("data-open"))),
             "backdrop clicks must never dismiss an AlertDialog"
      refute_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display))

      # Esc reaches the controller as the native cancel event; close()
      # ignores dismissibleValue (escape is always an answer: cancel).
      harness.execute(<<~JS)
        document.querySelector("dialog")
          .dispatchEvent(new Event("cancel", { cancelable: true }));
      JS
      harness.pump

      assert_no_js_errors harness
      assert harness.evaluate(%(document.querySelector("dialog").hasAttribute("data-closed"))),
             "Esc (cancel) must still close - only pointer dismissal is suppressed"
      assert_equal "none",
                   harness.evaluate(%(getComputedStyle(document.querySelector("dialog")).display))
    end
  end
end
