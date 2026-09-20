# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Mixed marks on one shared cartesian. The contracts:
    # declaration order is paint order, every mark shares the band x and
    # ONE y domain, stack ids stay inside their mark type, and the tooltip
    # wire carries every series.
    class ComposedChartTest < ViewComponent::TestCase
      DATA = [
        { month: "January", visitors: 320, revenue: 214, trend: 240 },
        { month: "February", visitors: 410, revenue: 305, trend: 290 },
        { month: "March", visitors: 380, revenue: 237, trend: 320 }
      ].freeze

      CONFIG = {
        visitors: { label: "Visitors", color: "var(--chart-1)" },
        revenue: { label: "Revenue", color: "var(--chart-2)" },
        trend: { label: "Trend", color: "var(--chart-3)" }
      }.freeze

      def render_chart(**, &)
        render_inline(ComposedChart::Component.new(data: DATA, config: CONFIG, id: "c", **), &)
      end

      def test_declaration_order_is_paint_order
        html = render_chart do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_line(data_key: :trend)
          chart.with_bar(data_key: :visitors)
          chart.with_area(data_key: :revenue)
        end

        marks = html.css('[data-slot="chart-line"], [data-slot="chart-bar"], [data-slot="chart-area"]')
                    .map { |el| el["data-slot"] }.uniq

        assert_equal %w[chart-line chart-bar chart-area], marks,
                     "the line was declared first, so it paints first (recharts children order)"
      end

      def test_marks_share_the_band_x_and_one_y_domain
        html = render_chart do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :visitors)
          chart.with_line(data_key: :trend)
        end

        # The shared y domain spans max(visitors)=410 -> nice ticks to 500;
        # both marks must be scaled by IT (a line-only domain would top at
        # 320 and put January's trend point elsewhere).
        cartesian = Cartesian.new(
          data: DATA, width: 640, height: 360, x_key: "month",
          series: [ComposedChart::Component::Series.new(mark: :bar, key: "visitors", stack: nil, curve: nil,
                                                        fill_opacity: nil, gradient: nil, stroke_width: nil,
                                                        dots: nil, dot_radius: nil, radius: 0),
                   ComposedChart::Component::Series.new(mark: :line, key: "trend", stack: nil, curve: :natural,
                                                        fill_opacity: nil, gradient: nil, stroke_width: nil,
                                                        dots: nil, dot_radius: nil, radius: nil)],
          x_scale_type: :band
        )

        line = html.css('[data-slot="chart-line"]').first
        trend_entry = cartesian.instance_variable_get(:@series).last
        expected = Geometry::Line.new(
          x: ->(p, _i) { p[:x] }, y: ->(p, _i) { p[:y1] },
          curve: :natural, defined: ->(p, _i) { !p[:value].nan? }
        ).path(cartesian.points(trend_entry))

        assert_equal expected, line["d"]

        # Bars ride the same band scale.
        first_bar = html.css('[data-slot="chart-bar"]').first

        assert first_bar["d"].start_with?("M"), "bar path present"
      end

      def test_stack_ids_stay_inside_their_mark_type
        html = render_chart do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_area(data_key: :revenue, stack: :a)
          chart.with_bar(data_key: :visitors, stack: :a)
        end

        component = ComposedChart::Component.new(data: DATA, config: CONFIG, id: "c")
        render_inline(component) do |chart|
          chart.with_area(data_key: :revenue, stack: :a)
          chart.with_bar(data_key: :visitors, stack: :a)
        end

        stacks = component.series_entries.map(&:stack)

        assert_equal %w[area-a bar-a], stacks, "the same user stack id never co-stacks across marks"
        assert_predicate html.css('[data-slot="chart-area"]'), :any?
      end

      def test_the_tooltip_wire_carries_every_mark
        html = render_chart do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :visitors)
          chart.with_line(data_key: :trend, dots: true)
          chart.with_tooltip
        end

        payload = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_equal %w[visitors trend], payload["values"].keys
        assert_equal %w[320 410 380], payload["values"]["visitors"]

        # Bars reflect via data-index; only the line gets active dots.
        active_keys = html.css('[data-slot="chart-active-dot"]').map { |dot| dot["data-key"] }.uniq

        assert_equal %w[trend], active_keys
        assert_equal(%w[0 1 2], html.css('[data-slot="chart-bar"]').map { |bar| bar["data-index"] })
      end

      def test_the_helper_dispatches_composed
        html = vc_test_controller.view_context.poetry_chart(
          :composed, data: DATA, config: CONFIG, id: "c"
        ) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :visitors)
        end

        assert_includes html, "chart-bar"
      end
    end
  end
end
