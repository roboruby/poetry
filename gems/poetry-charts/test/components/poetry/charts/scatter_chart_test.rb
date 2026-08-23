# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Both axes numeric (recharts-niced linear scales),
    # per-point marks with global indexes, z sizing on recharts' AREA
    # semantics, and the per-index tooltip wire.
    class ScatterChartTest < ViewComponent::TestCase
      DATA = [
        { height: 161, weight: 51, bmi: 19.7 },
        { height: 170, weight: 68, bmi: 23.5 },
        { height: 189, weight: 95, bmi: 26.6 }
      ].freeze

      CONFIG = {
        sample: { label: "Sample", color: "var(--chart-1)" },
        control: { label: "Control", color: "var(--chart-2)" }
      }.freeze

      def render_chart(**options, &extra)
        render_inline(ScatterChart::Component.new(data: DATA, config: CONFIG, id: "s", **options)) do |chart|
          chart.with_grid
          chart.with_x_axis(data_key: :height)
          chart.with_y_axis(data_key: :weight)
          extra&.call(chart)
          chart.with_scatter(key: :sample)
        end
      end

      def test_points_sit_on_two_recharts_niced_linear_scales
        html = render_chart

        x_ticks = Geometry::NiceTicks.nice_ticks([0, 189], 5)
        y_ticks = Geometry::NiceTicks.nice_ticks([0, 95], 5)
        x_scale = Geometry::Scale::Linear.new(domain: [x_ticks.first, x_ticks.last], range: [65.0, 635.0])
        y_scale = Geometry::Scale::Linear.new(domain: [y_ticks.first, y_ticks.last], range: [325.0, 5.0])

        point = html.css('[data-slot="chart-scatter-point"]').first

        assert_equal Geometry.js_number((x_scale.call(161) * 100).round / 100.0), point["cx"]
        assert_equal Geometry.js_number((y_scale.call(51) * 100).round / 100.0), point["cy"]

        # Default marker: recharts ZAxis range [64, 64] px2 -> r = sqrt(64/pi).
        assert_in_delta Math.sqrt(64 / Math::PI), point["r"].to_f, 0.01

        tick_labels = html.css('[data-slot="chart-x-axis"] text').map(&:text)

        assert_equal x_ticks.map { |t| Geometry.js_number(t.to_f) }, tick_labels
      end

      def test_z_axis_sizes_points_by_area
        html = render_chart do |chart|
          chart.with_z_axis(data_key: :bmi, range: [64, 400])
        end

        radii = html.css('[data-slot="chart-scatter-point"]').map { |p| p["r"].to_f }

        # bmi 19.7 -> area 64 (domain min), bmi 26.6 -> area 400 (domain max).
        assert_in_delta Math.sqrt(64 / Math::PI), radii.first, 0.01
        assert_in_delta Math.sqrt(400 / Math::PI), radii.last, 0.01
        assert radii[1].between?(radii.first, radii.last)
      end

      def test_multiple_series_flatten_into_one_global_index_space
        html = render_inline(ScatterChart::Component.new(data: DATA, config: CONFIG, id: "s")) do |chart|
          chart.with_x_axis(data_key: :height)
          chart.with_y_axis(data_key: :weight)
          chart.with_scatter(key: :sample)
          chart.with_scatter(key: :control, data: [{ height: 165, weight: 71 }])
          chart.with_tooltip
        end

        points = html.css('[data-slot="chart-scatter-point"]')

        assert_equal(%w[0 1 2 3], points.map { |p| p["data-index"] })
        assert_equal(%w[sample sample sample control], points.map { |p| p["data-key"] })

        payload = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_equal "polar", payload["layout"], "per-index anchors mode - the controller's pie wire"
        assert_equal 4, payload["anchors"].length
        assert_equal %w[Sample Sample Sample Control], payload["categories"],
                     "the point's series shows as the tooltip label"
        assert_nil payload["names"], "the x/y rows keep their axis labels"
        assert_equal %w[161 170 189 165], payload["values"]["x"]
        assert_equal %w[51 68 95 71], payload["values"]["y"]
      end

      def test_the_tooltip_chrome_rows_are_the_axis_dimensions
        html = render_chart(&:with_tooltip)

        rows = html.css('[data-slot="chart-tooltip-item"]')

        assert_equal(%w[x y], rows.map { |row| row["data-key"] })
        assert_includes html.css('[data-slot="chart-svg"]').first["data-action"], "pointerover->"
      end

      def test_scatter_defaults_to_recharts_linear_400ms
        html = render_chart
        style = html.css('[data-slot="chart-svg"]').first["style"]

        assert_includes style, "--poetry-motion-duration: 400ms"
        assert_includes style, "--poetry-motion-easing: linear"
      end

      def test_the_helper_dispatches_scatter
        html = vc_test_controller.view_context.poetry_chart(
          :scatter, data: DATA, config: CONFIG, id: "s"
        ) do |chart|
          chart.with_x_axis(data_key: :height)
          chart.with_y_axis(data_key: :weight)
          chart.with_scatter(key: :sample)
        end

        assert_includes html, "chart-scatter-point"
      end
    end
  end
end
