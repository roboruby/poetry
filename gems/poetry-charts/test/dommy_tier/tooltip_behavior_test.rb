# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The tooltip engine end-to-end: REAL chart markup (server-embedded
  # coordinates + pre-formatted values) driven by the REAL
  # poetry--charts--tooltip controller. The defining moves live here
  # because they are layout-free: the keyboard accessibility layer walks
  # the categories and swaps values into the pre-rendered chrome, active
  # marks reflect data-active, Escape dismisses, and synced charts follow
  # each other's active index. The pointermove bisect and box positioning
  # read getBoundingClientRect - browser-pass territory, skipped here (the
  # controller guards on zero rects).
  class TooltipBehaviorTest < TestCase
    DATA = [
      { month: "January", desktop: 186, mobile: 80 },
      { month: "February", desktop: 3050, mobile: 200 },
      { month: "March", desktop: 237, mobile: nil }
    ].freeze

    CONFIG = {
      desktop: { label: "Desktop", color: "var(--chart-1)" },
      mobile: { label: "Mobile", color: "var(--chart-2)" }
    }.freeze

    def chart(id: "t", sync: nil)
      Poetry::Charts::AreaChart::Component.new(data: DATA, config: CONFIG, id: id,
                                               **(sync ? { sync: sync } : {})).tap do |component|
        component.with_x_axis(data_key: :month)
        component.with_area(data_key: :desktop)
        component.with_area(data_key: :mobile)
        component.with_tooltip(indicator: :line)
      end
    end

    def arrow(harness, scope = "")
      harness.execute(<<~JS)
        document.querySelector('#{scope}[data-slot="chart-svg"]').dispatchEvent(
          new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 5)
    end

    def tooltip_state(harness, scope = "")
      harness.evaluate(<<~JS)
        (() => {
          const tooltip = document.querySelector('#{scope}[data-slot="chart-tooltip"]');
          const label = tooltip.querySelector('[data-slot="chart-tooltip-label"]');
          const values = [...tooltip.querySelectorAll('[data-slot="chart-tooltip-item"]')].map((row) =>
            [row.dataset.key, row.querySelector('[data-slot="chart-tooltip-value"]').textContent,
             row.style.display]);
          return [tooltip.hidden, label && label.textContent, values];
        })()
      JS
    end

    def test_the_keyboard_layer_walks_categories_and_serves_preformatted_values
      harness = render_in_dommy(chart)

      assert_no_js_errors harness

      arrow(harness)

      hidden, label, values = tooltip_state(harness)

      refute hidden, "ArrowRight from rest shows index 0"
      assert_equal "January", label
      assert_equal([%w[desktop 186], %w[mobile 80]], values.map { |key, value, _| [key, value] })

      arrow(harness)
      _, label, values = tooltip_state(harness)

      assert_equal "February", label
      assert_equal "3,050", values[0][1], "values are PRE-FORMATTED server strings (delimiters intact)"

      arrow(harness)
      _, label, values = tooltip_state(harness)

      assert_equal "March", label
      assert_equal "none", values[1][2], "a nil datum hides its row"
    end

    def test_active_marks_reflect_and_escape_dismisses
      harness = render_in_dommy(chart)
      arrow(harness)

      shown = harness.evaluate(<<~JS)
        [...document.querySelectorAll('[data-slot="chart-active-dot"]')]
          .filter((dot) => dot.getAttribute("display") !== "none")
          .map((dot) => dot.dataset.index)
      JS

      assert_equal %w[0 0], shown, "one active dot per series, at the active index"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="chart-svg"]').dispatchEvent(
          new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 5)

      hidden, = tooltip_state(harness)

      assert hidden, "Escape dismisses"
      assert_no_js_errors harness
    end

    def test_synced_charts_follow_each_others_active_index
      first = render_inline(chart(id: "s1", sync: "grp")).to_html
      second = render_inline(chart(id: "s2", sync: "grp")).to_html
      harness = render_in_dommy(first + second)

      arrow(harness, '[data-chart="chart-s1"] ')
      arrow(harness, '[data-chart="chart-s1"] ')

      assert_no_js_errors harness
      hidden, label, = tooltip_state(harness, '[data-chart="chart-s2"] ')

      refute hidden, "the second chart followed the sync broadcast"
      assert_equal "February", label
    end
  end
end
