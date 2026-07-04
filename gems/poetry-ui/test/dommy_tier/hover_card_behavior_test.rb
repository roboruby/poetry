# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL HoverCard markup driven by the REAL poetry--core--hover-card
  # controller: the structure dommy can honestly see - the trigger is a
  # plain link with NO aria surface; focus opens IMMEDIATELY (the focus
  # mirror: a keyboard user SEES the card) and token-activates the
  # dismissable layer; the per-open TABINDEX STRIP forces every tabbable
  # inside to -1 (keyboard users never reach inside - the
  # reachable-elsewhere rule's enforcement); blur closes with nothing to
  # restore (focus never moved in). Hover delays, the selection hold, and
  # touch emulation stay with the browser pass.
  class HoverCardBehaviorTest < TestCase
    def render_card(**)
      component = Poetry::Ui::HoverCard::Component.new(**)
      component.with_trigger(href: "https://github.com/nextjs") { "@nextjs" }
      component.with_content(
        '<p>The React Framework.</p><a href="https://vercel.com">vercel</a><button type="button">Follow</button>'
          .html_safe
      )
      render_in_dommy(component)
    end

    def card_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="hover-card-trigger"]');
          const content = document.querySelector('[data-slot="hover-card-content"]');
          const contentState = content.hasAttribute("data-open") ? "open"
            : content.hasAttribute("data-closed") ? "closed" : "none";
          return [trigger.hasAttribute("data-popup-open"), contentState, content.hidden];
        })()
      JS
    end

    def test_focus_opens_immediately_and_strips_every_tabbable_inside
      harness = render_card

      assert_no_js_errors harness
      assert_equal [false, "closed", true], card_state(harness), "server-rendered closed"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="hover-card-trigger"]')
          .dispatchEvent(new Event("focus"));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal [true, "open", false], card_state(harness), "focus opens with no delay (the focus mirror)"

      stripped = harness.evaluate(<<~JS)
        (() => {
          const content = document.querySelector('[data-slot="hover-card-content"]');
          return [...content.querySelectorAll("a, button")].map((el) => el.getAttribute("tabindex"));
        })()
      JS

      # The tabindex strip (Radix-exact): the card is sighted-pointer-only
      # BY DESIGN - Tab passes straight over its contents.
      assert_equal ["-1", "-1"], stripped

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="hover-card-content"]').getAttribute("data-controller"))
      )

      assert_includes controllers, "poetry--core--dismissable"
      refute_includes controllers, "poetry--core--focus-scope", "no focus-scope anywhere in the lifecycle"
    end

    def test_the_trigger_exposes_no_aria_surface_in_the_live_dom
      harness = render_card

      aria = harness.evaluate(<<~JS)
        (() => {
          const trigger = document.querySelector('[data-slot="hover-card-trigger"]');
          return [trigger.tagName.toLowerCase(), trigger.getAttribute("href"),
                  trigger.getAttribute("aria-haspopup"), trigger.getAttribute("aria-expanded"),
                  trigger.getAttribute("aria-describedby")];
        })()
      JS

      assert_equal ["a", "https://github.com/nextjs", nil, nil, nil], aria,
                   "a real link, invisible to AT as a popup (Radix-exact silence)"
    end

    def test_blur_closes_and_removes_the_layer_token
      harness = render_card

      harness.execute(<<~JS)
        document.querySelector('[data-slot="hover-card-trigger"]')
          .dispatchEvent(new Event("focus"));
      JS
      harness.pump(rounds: 10)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="hover-card-trigger"]')
          .dispatchEvent(new Event("blur"));
      JS
      # The exit rides presence's animationend/timeout fallback.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal [false, "closed", true], card_state(harness), "blur closes immediately"

      controllers = harness.evaluate(
        %(document.querySelector('[data-slot="hover-card-content"]').getAttribute("data-controller"))
      )

      refute_includes controllers.to_s, "poetry--core--dismissable"
    end
  end
end
