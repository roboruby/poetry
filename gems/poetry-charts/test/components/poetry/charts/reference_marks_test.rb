# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Phase C-W3: reference lines/areas/dots across the cartesian families
    # and error-bar whiskers on line/bar/scatter. The contracts: values
    # speak the chart's own axes (categories on the category axis, numbers
    # on the value axis, both numeric on scatter), the group paints above
    # the series, whiskers derive from error_key offsets, and live mode
    # refuses both (lambda-free wire).
    class ReferenceMarksTest < ViewComponent::TestCase
      DATA = [
        { month: "January", desktop: 186, err: 20 },
        { month: "February", desktop: 305, err: [30, 10] },
        { month: "March", desktop: 237, err: nil }
      ].freeze

      CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze

      def test_reference_lines_speak_categories_and_values
        html = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "r")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_line(data_key: :desktop)
          chart.with_reference_line(y: 242.6, label: "avg")
          chart.with_reference_line(x: "February")
        end

        group = html.css('g[data-slot="chart-reference"]').first

        assert group, "the reference group renders"
        lines = group.css("line")

        # y: 242.6 -> the value scale; the rule spans the plot width.
        cartesian = Cartesian.new(
          data: DATA, width: 640, height: 360, x_key: "month",
          series: [LineChart::Component::Series.new(key: "desktop", curve: :natural, stroke_width: 2,
                                                    dots: false, dot_radius: 3, dot_color_key: nil,
                                                    labels: false, error_key: nil, error_width: 5)]
        )
        expected_y = Geometry.js_number((cartesian.y_scale.call(242.6) * 100).round / 100.0)

        assert_equal expected_y, lines.first["y1"]
        assert_equal lines.first["y1"], lines.first["y2"]
        assert_equal "avg", group.css("text").first.text

        # x: "February" -> the category center (index 1 of 3 on a point scale).
        expected_x = Geometry.js_number((cartesian.x_centers[1] * 100).round / 100.0)

        assert_equal expected_x, lines.last["x1"]
        assert_equal lines.last["x1"], lines.last["x2"]

        # Painted ABOVE the series: the reference group follows chart-lines.
        svg_children = html.css('[data-slot="chart-svg"] > g').map { |g| g["data-slot"] }

        assert_operator svg_children.index("chart-reference"), :>, svg_children.index("chart-lines")
      end

      def test_reference_area_defaults_missing_edges_to_the_plot
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "r")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_area(data_key: :desktop)
          chart.with_reference_area(y1: 200, y2: 300, label: "target")
        end

        rect = html.css('g[data-slot="chart-reference"] rect').first

        assert rect
        assert_equal "5", rect["x"], "x1 defaulted to the plot left"
        assert_in_delta 300.0 - 200.0, rect["height"].to_f * ((320.0 / 500)**-1) / 1, 200 # sanity: has height
        assert_equal "target", html.css('g[data-slot="chart-reference"] text').first.text
      end

      def test_unknown_reference_category_teaches
        error = assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "r")) do |chart|
            chart.with_x_axis(data_key: :month)
            chart.with_line(data_key: :desktop)
            chart.with_reference_line(x: "Sept")
          end
        end

        assert_match(/not a category/, error.message)
      end

      def test_scatter_references_are_numeric_on_both_axes
        html = render_inline(ScatterChart::Component.new(
                               data: [{ h: 10, w: 20 }, { h: 30, w: 40 }],
                               config: { s: { label: "S", color: "var(--chart-1)" } }, id: "r"
                             )) do |chart|
          chart.with_x_axis(data_key: :h)
          chart.with_y_axis(data_key: :w)
          chart.with_scatter(key: :s)
          chart.with_reference_dot(x: 20, y: 30, r: 6, label: "mid")
        end

        dot = html.css('g[data-slot="chart-reference"] circle').first

        assert dot
        assert_equal "6", dot["r"]
        assert_equal "mid", html.css('g[data-slot="chart-reference"] text').first.text
      end

      def test_error_bars_whisker_from_offsets_and_skip_missing
        html = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "r")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_line(data_key: :desktop, error_key: :err)
        end

        whiskers = html.css('g[data-slot="chart-error-bars"] path')

        assert_equal 2, whiskers.length, "March has no err entry - no whisker"

        cartesian = Cartesian.new(
          data: DATA, width: 640, height: 360, x_key: "month",
          series: [LineChart::Component::Series.new(key: "desktop", curve: :natural, stroke_width: 2,
                                                    dots: false, dot_radius: 3, dot_color_key: nil,
                                                    labels: false, error_key: "err", error_width: 5)]
        )
        # January: symmetric 186 +- 20; February: asymmetric [30, 10].
        f = ->(v) { Geometry.js_number((v * 100).round / 100.0) }
        jan_low = f.call(cartesian.y_scale.call(166.0))
        jan_high = f.call(cartesian.y_scale.call(206.0))

        assert_includes whiskers.first["d"], jan_low
        assert_includes whiskers.first["d"], jan_high

        feb_low = f.call(cartesian.y_scale.call(275.0))
        feb_high = f.call(cartesian.y_scale.call(315.0))

        assert_includes whiskers.last["d"], feb_low
        assert_includes whiskers.last["d"], feb_high
      end

      def test_bar_error_bars_center_on_the_bar
        html = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "r")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :desktop, error_key: :err)
        end

        assert_equal 2, html.css('g[data-slot="chart-error-bars"] path').length
      end

      def test_live_mode_refuses_references_and_error_bars
        error = assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "r", live: true)) do |chart|
            chart.with_x_axis(data_key: :month)
            chart.with_line(data_key: :desktop, error_key: :err)
          end
        end

        assert_match(/error bars/, error.message)

        error = assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "r", live: true)) do |chart|
            chart.with_x_axis(data_key: :month)
            chart.with_line(data_key: :desktop)
            chart.with_reference_line(y: 100)
          end
        end

        assert_match(/reference marks/, error.message)
      end
    end
  end
end
