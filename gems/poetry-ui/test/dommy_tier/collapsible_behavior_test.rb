# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end disclosure: the REAL Collapsible markup driven by the REAL
  # poetry--core--state controller (registration, targets, actions, the
  # presence helper) - a bad identifier or a broken target contract shows
  # up here as connect()/toggle() never firing.
  class CollapsibleBehaviorTest < TestCase
    def render_collapsible(**options)
      render_in_dommy(Poetry::Ui::Collapsible::Component.new(**options)) do |collapsible|
        collapsible.with_trigger { "Show details" }
        collapsible.with_content("the details")
      end
    end

    def click_trigger(harness)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="collapsible-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      # Generous virtual time: exitPresence may defer `hidden` behind an
      # animation-length timeout (the clock is simulated - this costs ~0 wall).
      harness.pump(rounds: 80)

      assert_no_js_errors harness
    end

    def disclosure_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('[data-slot="collapsible"]');
          const state = root.hasAttribute("data-open") ? "open"
            : (root.hasAttribute("data-closed") ? "closed" : null);
          return [document.querySelector('[data-slot="collapsible-trigger"]').getAttribute("aria-expanded"),
                  document.querySelector('[data-slot="collapsible-content"]').hidden,
                  state];
        })()
      JS
    end

    def test_clicking_the_real_trigger_flips_aria_expanded_and_hidden
      harness = render_collapsible

      assert_no_js_errors harness

      assert_equal ["false", true, "closed"], disclosure_state(harness), "server-rendered closed"

      click_trigger(harness)

      assert_equal ["true", false, "open"], disclosure_state(harness), "first click opens"

      click_trigger(harness)

      assert_equal ["false", true, "closed"], disclosure_state(harness), "second click closes"
    end
  end
end
