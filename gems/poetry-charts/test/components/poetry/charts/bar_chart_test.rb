# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # N10 W4a: the bar family render contracts - the recharts band math
    # (10% category trim, 4px gaps, stacked share a slot), per-corner
    # radius paths, negatives below the zero line, guarded per-cell fills,
    # and the active highlight.
    class BarChartTest < ViewComponent::TestCase
      DATA = [
        { month: "January", desktop: 186, mobile: 80 },
        { month: "February", desktop: 305, mobile: 200 },
        { month: "March", desktop: 237, mobile: 120 },
        { month: "April", desktop: 73, mobile: 190 },
        { month: "May", desktop: 209, mobile: 130 },
        { month: "June", desktop: 214, mobile: 140 }
      ].freeze

      CONFIG = {
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      def render_chart(id: "test", data: DATA, **options)
        render_inline(BarChart::Component.new(data: data, config: CONFIG, id: id, **options)) do |chart|
          chart.with_grid
          chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
          yield chart
        end
      end

      def test_bars_follow_the_recharts_band_math
        html = render_chart { |chart| chart.with_bar(data_key: :desktop) }

        bars = html.css('[data-slot="chart-bar"]')

        assert_equal DATA.length, bars.length
        # plot width 630 (margins 5), 6 categories -> band 105; 10% trim
        # each side -> size 105 - 21 = 84 (rounded).
        first_x = Float(bars.first["d"][/M([\d.]+),/, 1])

        assert_in_delta 5 + 10.5, first_x, 0.02, "first bar starts at band + 10% trim"
      end

      def test_side_by_side_groups_split_the_band_with_the_4px_gap
        html = render_chart do |chart|
          chart.with_bar(data_key: :desktop, radius: 4)
          chart.with_bar(data_key: :mobile, radius: 4)
        end

        desktop_x = Float(html.css('[data-slot="chart-bar"][data-key="desktop"]').first["d"][/M([\d.]+),/, 1])
        mobile_x = Float(html.css('[data-slot="chart-bar"][data-key="mobile"]').first["d"][/M([\d.]+),/, 1])

        # size = round((105 - 21 - 4) / 2) = 40; mobile offset = size + gap = 44.
        assert_in_delta 44.0, mobile_x - desktop_x, 0.02
      end

      def test_stacked_bars_share_a_slot_and_accumulate
        html = render_chart do |chart|
          chart.with_bar(data_key: :desktop, stack: :a, radius: [0, 0, 4, 4])
          chart.with_bar(data_key: :mobile, stack: :a, radius: [4, 4, 0, 0])
        end

        desktop = html.css('[data-slot="chart-bar"][data-key="desktop"]').first
        mobile = html.css('[data-slot="chart-bar"][data-key="mobile"]').first
        desktop_x = Float(desktop["d"][/M([\d.]+),/, 1])
        mobile_x = Float(mobile["d"][/M([\d.]+),/, 1])

        assert_in_delta 0.0, (mobile_x - desktop_x).abs, 4.1, "stacked bars share the slot"
        # The bottom bar starts with no top arc; the top bar has one.
        refute_includes desktop["d"][0, 30], "A", "bottom bar's top corners are square"
        assert_includes mobile["d"][0, 40], "A", "top bar's top corners are rounded"
      end

      def test_radius_rounds_all_corners_when_numeric
        html = render_chart { |chart| chart.with_bar(data_key: :desktop, radius: 8) }

        d = html.css('[data-slot="chart-bar"]').first["d"]

        assert_equal 4, d.scan("A").length, "radius: 8 arcs all four corners"
        assert_includes d, "A8,8,0,0,1"
      end

      def test_negative_values_drop_below_the_zero_line
        data = [{ month: "March", visitors: -207 }, { month: "June", visitors: 214 }]
        html = render_chart(data: data) do |chart|
          chart.with_bar(data_key: :visitors,
                         cell_fill: ->(_row, value) { value.positive? ? "var(--chart-1)" : "var(--chart-2)" })
        end

        bars = html.css('[data-slot="chart-bar"]')

        assert_equal "var(--chart-2)", bars.first["fill"], "negative cells take the sign color"
        assert_equal "var(--chart-1)", bars.last["fill"]

        negative_top = Float(bars.first["d"][/M[\d.]+,([\d.]+)/, 1])
        positive_top = Float(bars.last["d"][/M[\d.]+,([\d.]+)/, 1])

        assert_operator negative_top, :>, positive_top,
                        "the negative bar's rect starts AT the zero line (below the positive's top)"
      end

      def test_unsafe_cell_fills_raise
        assert_raises(ArgumentError) do
          render_chart do |chart|
            chart.with_bar(data_key: :desktop, cell_fill: ->(_r, _v) { "red;}body{}" })
          end
        end
      end

      def test_the_active_index_wears_the_highlight
        data = [{ browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
                { browser: "safari", visitors: 200, fill: "var(--color-safari)" }]
        html = render_inline(BarChart::Component.new(data: data, config: CONFIG, id: "active")) do |chart|
          chart.with_x_axis(data_key: :browser)
          chart.with_bar(data_key: :visitors, color_key: :fill, active_index: 1)
        end

        active = html.css('[data-slot="chart-bar"][data-active]')

        assert_equal 1, active.length
        assert_equal "1", active.first["data-index"]
        assert_equal "0.8", active.first["fill-opacity"]
        assert_equal "4", active.first["stroke-dasharray"]
        assert_equal "var(--color-safari)", active.first["stroke"], "the dashed stroke takes the cell fill"
      end

      def test_labels_stamp_above_bars_with_label_key_support
        html = render_chart { |chart| chart.with_bar(data_key: :desktop, labels: true, label_key: :month) }

        labels = html.css('[data-slot="chart-labels"] text')

        assert_equal DATA.map { |d| d[:month] }, labels.map(&:text)
      end

      def test_the_dispatcher_routes_bar
        html = vc_test_controller.view_context.poetry_chart(:bar, data: DATA, config: CONFIG, id: "via") do |chart|
          chart.with_bar(data_key: :desktop)
        end

        assert_includes html, "chart-bar"
      end
    end
  end
end
