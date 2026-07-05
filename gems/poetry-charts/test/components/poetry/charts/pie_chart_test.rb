# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # N10 W6a: the pie family render contracts - row-fill slices, the donut
    # hole, nested stacked rings, the center label, inside labels, the
    # popped active slice, and the polar tooltip payload (names/colors/
    # anchors driving the single retinted chrome row).
    class PieChartTest < ViewComponent::TestCase
      CONFIG = {
        visitors: { label: "Visitors" },
        chrome: { label: "Chrome", color: "var(--chart-1)" },
        safari: { label: "Safari", color: "var(--chart-2)" },
        firefox: { label: "Firefox", color: "var(--chart-3)" },
        edge: { label: "Edge", color: "var(--chart-4)" },
        other: { label: "Other", color: "var(--chart-5)" }
      }.freeze

      DATA = [
        { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
        { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
        { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
        { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
        { browser: "other", visitors: 90, fill: "var(--color-other)" }
      ].freeze

      MONTH_DATA = [
        { month: "january", desktop: 186, fill: "var(--color-january)" },
        { month: "february", desktop: 305, fill: "var(--color-february)" },
        { month: "march", desktop: 237, fill: "var(--color-march)" }
      ].freeze

      STACKED_CONFIG = CONFIG.merge(
        desktop: { label: "Desktop" },
        january: { label: "January", color: "var(--chart-1)" },
        february: { label: "February", color: "var(--chart-2)" },
        march: { label: "March", color: "var(--chart-3)" }
      ).freeze

      def render_pie(**, &)
        render_inline(PieChart::Component.new(data: DATA, config: CONFIG, id: "p", **), &)
      end

      def test_slices_take_their_row_fills_and_background_separators
        html = render_pie { |chart| chart.with_pie(data_key: :visitors, name_key: :browser) }

        sectors = html.css('[data-slot="chart-pie-sector"]')

        assert_equal 5, sectors.length
        assert_equal "var(--color-chrome)", sectors.first["fill"]
        assert_equal "var(--background)", sectors.first["stroke"],
                     "the separator is background-colored (dark-mode-correct; recharts hard-codes #fff)"
        assert sectors.first["d"].end_with?("Z")
      end

      def test_the_donut_hole_comes_from_inner_radius
        html = render_pie { |chart| chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60) }

        d = html.css('[data-slot="chart-pie-sector"]').first["d"]

        assert_equal 2, d.scan("A").length, "donut sectors arc both radii"
        assert_includes d, "A60,60,0,", "the inner radius is 60"
      end

      def test_the_center_label_fills_the_hole
        html = render_pie do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60)
          chart.with_center_label(title: "925", subtitle: "Visitors")
        end

        label = html.css('[data-slot="chart-center-label"]').first

        assert_equal %w[925 Visitors], label.css("tspan").map(&:text)
        assert_equal "320", label["x"], "centered in the plot box"
      end

      def test_stacked_pies_nest_two_rings_with_their_own_data
        html = render_inline(PieChart::Component.new(config: STACKED_CONFIG, id: "s")) do |chart|
          chart.with_pie(data: DATA, data_key: :visitors, name_key: :browser, outer_radius: 60)
          chart.with_pie(data: MONTH_DATA, data_key: :desktop, name_key: :month,
                         inner_radius: 70, outer_radius: 90)
        end

        groups = html.css('[data-slot="chart-pie"]')

        assert_equal(%w[visitors desktop], groups.map { |g| g["data-key"] })
        assert_equal 3, groups.last.css("path").length
        # Only the FIRST pie drives the tooltip index space.
        assert_empty groups.last.css("[data-index]")
      end

      def test_inside_labels_ride_the_middle_radius
        html = render_pie do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser, labels: :list, label_key: :browser)
        end

        labels = html.css('[data-slot="chart-labels"] text')

        assert_equal %w[chrome safari firefox edge other], labels.map(&:text)
        assert_includes labels.first["class"], "fill-background"
      end

      def test_the_active_slice_pops_outward
        html = render_pie do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60, active_index: 0)
        end

        active = html.css('[data-slot="chart-pie-sector"][data-active]').first

        assert active
        assert_includes active["d"], "A150,150,0,", "the active outer radius grows by 10 (140 -> 150)"
        inactive = html.css('[data-slot="chart-pie-sector"]:not([data-active])').first

        assert_includes inactive["d"], "A140,140,0,"
      end

      def test_the_polar_tooltip_payload_retints_the_single_row
        html = render_pie do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser)
          chart.with_tooltip
        end

        payload = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_equal "polar", payload["layout"]
        assert_equal %w[Chrome Safari Firefox Edge Other], payload["names"]
        assert_equal "var(--color-chrome)", payload["colors"].first
        assert_equal 5, payload["anchors"].length
        assert_equal "275", payload["values"]["visitors"].first
        svg = html.css('[data-slot="chart-svg"]').first

        assert_includes svg["data-action"], "pointerover->poetry--charts--tooltip#enter"
        rows = html.css('[data-slot="chart-tooltip-item"]')

        assert_equal ["visitors"], rows.map { |row| row["data-key"] }, "one chrome row, retinted per slice"
      end

      def test_unsafe_row_fills_raise
        data = [{ browser: "evil", visitors: 1, fill: "red;}*{}" }]

        assert_raises(ArgumentError) do
          render_inline(PieChart::Component.new(data: data, config: CONFIG, id: "e")) do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser)
          end
        end
      end

      def test_the_dispatcher_routes_pie
        html = vc_test_controller.view_context.poetry_chart(:pie, data: DATA, config: CONFIG,
                                                                  id: "via") do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser)
        end

        assert_includes html, "chart-pie-sector"
      end
    end
  end
end
