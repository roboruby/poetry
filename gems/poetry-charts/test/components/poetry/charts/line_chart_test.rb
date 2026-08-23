# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The line family render contracts - stroked curves only
    # (no fills), stroke-width 2 defaults, the dots variants (series color
    # and per-point colors), and point labels.
    class LineChartTest < ViewComponent::TestCase
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

      MARGIN = { left: 12, right: 12 }.freeze

      def render_chart(id: "test", **options)
        render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: id,
                                               margin: MARGIN, **options)) do |chart|
          chart.with_grid
          chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
          yield chart
        end
      end

      def test_lines_are_stroked_curves_with_no_fill
        html = render_chart { |chart| chart.with_line(data_key: :desktop) }

        path = html.css('[data-slot="chart-line"]').first

        assert_equal "none", path["fill"]
        assert_equal "var(--color-desktop)", path["stroke"]
        assert_equal "2", path["stroke-width"], "the shadcn block default"
        assert path["d"].start_with?("M")
        assert_empty html.css('[data-slot="chart-area"]'), "lines never fill"
      end

      def test_the_path_matches_the_geometry_oracle
        html = render_chart { |chart| chart.with_line(data_key: :desktop, curve: :natural) }

        cartesian = Cartesian.new(
          data: DATA, width: 640, height: 360, x_key: "month", margin: MARGIN,
          series: [LineChart::Component::Series.new(key: "desktop", curve: :natural, stroke_width: 2,
                                                    dots: false, dot_radius: 3, dot_color_key: nil,
                                                    labels: false, error_key: nil, error_width: 5)]
        )
        entry = cartesian.instance_variable_get(:@series).first
        expected = Geometry::Line.new(
          x: ->(p, _i) { p[:x] }, y: ->(p, _i) { p[:y1] },
          curve: :natural, defined: ->(p, _i) { !p[:value].nan? }
        ).path(cartesian.points(entry))

        assert_equal expected, html.css('[data-slot="chart-line"]').first["d"]
      end

      def test_multiple_lines_render_independently
        html = render_chart do |chart|
          chart.with_line(data_key: :desktop)
          chart.with_line(data_key: :mobile)
        end

        assert_equal(%w[desktop mobile], html.css('[data-slot="chart-line"]').map { |p| p["data-key"] })
      end

      def test_dots_render_solid_series_colored_circles
        html = render_chart { |chart| chart.with_line(data_key: :desktop, dots: true) }

        dots = html.css('[data-slot="chart-dot"]')

        assert_equal DATA.length, dots.length
        assert_equal "3", dots.first["r"]
        assert_equal "var(--color-desktop)", dots.first["fill"]
      end

      def test_per_point_dot_colors_read_the_data_key
        data = [
          { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
          { browser: "safari", visitors: 200, fill: "var(--color-safari)" }
        ]
        html = render_inline(LineChart::Component.new(data: data, config: CONFIG, id: "colors")) do |chart|
          chart.with_line(data_key: :visitors, dots: true, dot_radius: 5, dot_color_key: :fill)
        end

        dots = html.css('[data-slot="chart-dot"]')

        assert_equal(%w[var(--color-chrome) var(--color-safari)], dots.map { |d| d["fill"] })
        assert_equal "5", dots.first["r"]
      end

      def test_unsafe_dot_colors_raise
        data = [{ visitors: 1, fill: "red;}body{display:none" }]

        assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: data, config: CONFIG, id: "evil")) do |chart|
            chart.with_line(data_key: :visitors, dots: true, dot_color_key: :fill)
          end
        end
      end

      def test_labels_stamp_values_above_points
        html = render_chart { |chart| chart.with_line(data_key: :desktop, labels: true) }

        labels = html.css('[data-slot="chart-labels"] text')

        assert_equal DATA.map { |d| d[:desktop].to_s }, labels.map(&:text)
        coordinates = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_in_delta coordinates["series"]["desktop"][0] - 12, Float(labels.first["y"]), 0.02
      end

      def test_missing_values_gap_the_line_and_skip_markers
        data = DATA.map(&:dup)
        data[2][:desktop] = nil
        html = render_inline(LineChart::Component.new(data: data, config: CONFIG, id: "gap", margin: MARGIN)) do |chart|
          chart.with_line(data_key: :desktop, curve: :linear, dots: true)
        end

        d = html.css('[data-slot="chart-line"]').first["d"]

        assert_operator d.scan("M").length, :>=, 2, "a nil value splits the line into subpaths"
        assert_equal DATA.length - 1, html.css('[data-slot="chart-dot"]').length, "no dot for the missing point"
      end

      def test_the_dispatcher_routes_line
        html = vc_test_controller.view_context.poetry_chart(:line, data: DATA, config: CONFIG, id: "via") do |chart|
          chart.with_line(data_key: :desktop)
        end

        assert_includes html, "chart-line"
      end
    end
  end
end
