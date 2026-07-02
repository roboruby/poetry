# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end open-set machine: the REAL Accordion markup driven by the
  # REAL poetry--core--accordion controller. Single mode's defining move -
  # opening the second item closes the first - exercises toggle(), the
  # presence helper (the panels carry animate-accordion-up/down, so
  # `hidden` rides the exit timeout), and aria-expanded/aria-disabled
  # reflection.
  class AccordionBehaviorTest < TestCase
    def render_accordion
      render_in_dommy(Poetry::Ui::Accordion::Component.new(open: %w[one])) do |accordion|
        accordion.with_item(value: "one", title: "First") { "first panel" }
        accordion.with_item(value: "two", title: "Second") { "second panel" }
      end
    end

    def item_state(harness, value)
      harness.evaluate(<<~JS)
        (() => {
          const item = document.querySelector('[data-slot="accordion-item"][data-value="#{value}"]');
          return [item.dataset.state,
                  item.querySelector('[data-slot="accordion-trigger"]').getAttribute("aria-expanded"),
                  item.querySelector('[data-slot="accordion-content"]').hidden];
        })()
      JS
    end

    def test_single_mode_closes_the_open_item_when_another_opens
      harness = render_accordion

      assert_no_js_errors harness

      assert_equal ["open", "true", false], item_state(harness, "one"), "server-rendered open"
      assert_equal ["closed", "false", true], item_state(harness, "two"), "server-rendered closed"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="accordion-item"][data-value="two"] [data-slot="accordion-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      # The exit animation defers the closing panel's `hidden` behind a
      # timeout (up to presence's 1s fallback) - simulated clock, ~0 wall.
      harness.pump(rounds: 80)

      assert_no_js_errors harness

      assert_equal ["closed", "false", true], item_state(harness, "one"),
                   "single mode must close the first item"
      assert_equal ["open", "true", false], item_state(harness, "two"),
                   "the clicked item must open"
    end
  end
end
