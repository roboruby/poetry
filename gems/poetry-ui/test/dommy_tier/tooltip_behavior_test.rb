# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Tooltip markup driven by the REAL poetry--core--tooltip
  # controller: keyboard focus must open INSTANTLY (no delay - the Radix
  # focus path) with data-state=instant-open on both trigger and content,
  # write the open-only aria-describedby to the content id, and
  # token-activate the dismissable layer; blur must close and REMOVE the
  # describedby (a describedby to hidden content mis-announces); a second
  # tooltip opening must supersede the first (one open page-wide, the
  # will-open port). Hover delays / warm-grace timing and arrow geometry
  # stay with the browser pass.
  class TooltipBehaviorTest < TestCase
    def tooltip_html(text)
      component = Poetry::Ui::Tooltip::Component.new
      component.with_trigger(variant: :outline) { text }
      component.with_content("#{text} hint")
      render_inline(component).to_html
    end

    def tooltip_state(harness, index = 0)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelectorAll('[data-slot="tooltip-trigger"]')[#{index}];
          const content = document.querySelectorAll('[data-slot="tooltip-content"]')[#{index}];
          return [trigger.dataset.state, content.dataset.state, content.hidden,
                  trigger.getAttribute("aria-describedby")];
        })()
      JS
    end

    def focus_trigger(harness, index = 0)
      harness.execute(<<~JS)
        document.querySelectorAll('[data-slot="tooltip-trigger"]')[#{index}]
          .dispatchEvent(new Event("focus"));
      JS
      harness.pump(rounds: 10)
    end

    def test_focus_opens_instantly_and_wires_the_open_only_describedby
      harness = render_in_dommy(tooltip_html("Add"))

      assert_no_js_errors harness
      assert_equal ["closed", "closed", true, nil], tooltip_state(harness), "server-rendered closed, NO describedby"

      focus_trigger(harness)

      assert_no_js_errors harness
      content_id = harness.evaluate(%(document.querySelector('[data-slot="tooltip-content"]').id))

      assert_equal ["instant-open", "instant-open", false, content_id], tooltip_state(harness),
                   "focus opens instantly (the keyboard path skips all delays)"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="tooltip-content"]').getAttribute("data-controller"))
      )

      # Dismissable only - focus-scope is NOT composed at all (focus never
      # enters a tooltip, the defining trio contrast).
      assert_includes controllers, "poetry--core--dismissable"
      refute_includes controllers, "poetry--core--focus-scope"
    end

    def test_blur_closes_and_removes_the_describedby
      harness = render_in_dommy(tooltip_html("Add"))

      focus_trigger(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="tooltip-trigger"]')
          .dispatchEvent(new Event("blur"));
      JS
      # The exit rides presence's animationend/timeout fallback.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["closed", "closed", true, nil], tooltip_state(harness),
                   "blur closes; describedby is REMOVED (never references hidden content)"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="tooltip-content"]').getAttribute("data-controller"))
      )

      refute_includes controllers.to_s, "poetry--core--dismissable", "the layer token is removed after presence"
    end

    def test_a_second_tooltip_supersedes_the_first
      harness = render_in_dommy(tooltip_html("Add") + tooltip_html("Remove"))

      focus_trigger(harness, 0)

      assert_equal "instant-open", tooltip_state(harness, 0).first

      # Focus the second WITHOUT blurring the first: the document-level
      # will-open event must close tooltip A (one open page-wide).
      focus_trigger(harness, 1)
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal "closed", tooltip_state(harness, 0).first, "the first tooltip is superseded"
      assert_equal "instant-open", tooltip_state(harness, 1).first
    end
  end
end
