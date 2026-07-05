# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end month grid: the REAL Calendar markup driven by the REAL
  # poetry--core--calendar controller. The defining moves: a day click
  # selects it (hidden input + the vocabulary), and month nav regenerates
  # the 42 cells in place (labels + caption) - the own-the-engine grid,
  # exercised on the real DOM.
  class CalendarBehaviorTest < TestCase
    def render_calendar
      render_in_dommy(Poetry::Ui::Calendar::Component.new(
                        month: "2026-06-01", selected: "2026-06-12", today: "2026-06-15", name: "due_on"
                      ))
    end

    def day(harness, iso)
      harness.evaluate(<<~JS)
        (() => {
          const btn = document.querySelector('[data-slot="calendar-day"][data-date="#{iso}"]');
          if (!btn) return null;
          // aria-selected rides the role=gridcell parent (the ARIA grid contract).
          return [btn.hasAttribute("data-selected"), btn.closest('[role="gridcell"]').getAttribute("aria-selected")];
        })()
      JS
    end

    def test_clicking_a_day_selects_it_and_writes_the_form_value
      harness = render_calendar

      assert_no_js_errors harness
      assert_equal [true, "true"], day(harness, "2026-06-12"), "server-rendered selection"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="calendar-day"][data-date="2026-06-20"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      assert_equal [true, "true"], day(harness, "2026-06-20")
      assert_equal [false, "false"], day(harness, "2026-06-12"), "one selection at a time"
      input = harness.evaluate('document.querySelector(\'input[name="due_on"]\').value')

      assert_equal "2026-06-20", input, "the hidden form value updates"
    end

    def test_next_month_regenerates_the_grid_in_place
      harness = render_calendar

      harness.execute(<<~JS)
        document.querySelector('[data-slot="calendar-nav"] button:last-of-type')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      assert_no_js_errors harness
      caption = harness.evaluate('document.querySelector(\'[data-slot="calendar-caption"]\').textContent')

      assert_equal "July 2026", caption
      # July 4 2026 is now an in-month day.
      july = harness.evaluate(<<~JS)
        (() => {
          const btn = document.querySelector('[data-slot="calendar-day"][data-date="2026-07-04"]');
          return btn ? btn.hasAttribute("data-outside") : "missing";
        })()
      JS

      refute july, "July 4 is in-month after navigating forward"
    end
  end
end
