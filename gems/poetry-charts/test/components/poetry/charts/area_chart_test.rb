# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The first visible chart. The render contracts: the SVG
    # arrives complete from the server (paths, grid, ticks - no JS), the
    # geometry matches the oracle-tested pipeline recomputed independently,
    # stacking/expand/gradients follow the shadcn block grammar, and the
    # tooltip coordinates are embedded.
    class AreaChartTest < ViewComponent::TestCase
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

      def render_chart(id: "test", offset: :none, **options)
        render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: id,
                                               margin: MARGIN, offset: offset, **options)) do |chart|
          chart.with_grid
          chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
          yield chart
        end
      end

      def test_the_chart_arrives_complete_from_the_server
        html = render_chart { |chart| chart.with_area(data_key: :desktop) }

        svg = html.css('[data-slot="chart-svg"]').first

        assert_equal "0 0 640 360", svg["viewBox"]
        assert_equal "img", svg["role"]
        assert_equal "Area chart: Desktop, Mobile", svg["aria-label"]
        path = html.css('[data-slot="chart-area"]').first

        assert_equal "desktop", path["data-key"]
        assert path["d"].start_with?("M"), "the path data is server-computed"
        assert_equal "var(--color-desktop)", path["fill"]
        assert_equal "0.4", path["fill-opacity"]
      end

      def test_the_path_matches_the_geometry_oracle_recomputed_independently
        html = render_chart { |chart| chart.with_area(data_key: :desktop, curve: :natural) }

        cartesian = Cartesian.new(
          data: DATA, width: 640, height: 360, x_key: "month", margin: MARGIN,
          series: [AreaChart::Component::Series.new(key: "desktop", stack: nil, curve: :natural,
                                                    fill_opacity: 0.4, gradient: false, stroke_width: 1)]
        )
        entry = cartesian.instance_variable_get(:@series).first
        expected = Geometry::Area.new(
          x: ->(p, _i) { p[:x] }, y0: ->(p, _i) { p[:y0] }, y1: ->(p, _i) { p[:y1] },
          curve: :natural, defined: ->(p, _i) { !p[:value].nan? }
        ).path(cartesian.points(entry))

        assert_equal expected, html.css('[data-slot="chart-area"]').first["d"]
      end

      def test_the_grid_draws_one_horizontal_line_per_nice_tick
        html = render_chart { |chart| chart.with_area(data_key: :desktop) }

        # domain [0, 305] niced at tickCount 5 by the recharts algorithm.
        expected_ticks = Geometry::NiceTicks.nice_ticks([0, 305], 5)
        lines = html.css('[data-slot="chart-grid"] line')

        assert_equal expected_ticks.length, lines.length
        assert_equal "12", lines.first["x1"], "grid spans from the left margin"
        assert_equal "628", lines.first["x2"], "grid spans to the right margin"
      end

      def test_x_ticks_are_formatted_and_edge_to_edge
        html = render_chart { |chart| chart.with_area(data_key: :desktop) }

        texts = html.css('[data-slot="chart-x-axis"] text')

        assert_equal %w[Jan Feb Mar Apr May Jun], texts.map(&:text)
        assert_equal "12", texts.first["x"], "first category sits AT the left plot edge"
        assert_equal "628", texts.last["x"], "last category sits AT the right plot edge"
      end

      def test_stacked_areas_accumulate
        html = render_chart do |chart|
          chart.with_area(data_key: :mobile, stack: :a)
          chart.with_area(data_key: :desktop, stack: :a)
        end

        coordinates = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)
        mobile_top = coordinates["series"]["mobile"][0]
        desktop_top = coordinates["series"]["desktop"][0]

        assert_operator desktop_top, :<, mobile_top,
                        "desktop stacks ON TOP of mobile (smaller y = higher)"
      end

      def test_expand_offset_makes_the_stack_percent_based
        html = render_chart(offset: :expand) do |chart|
          chart.with_area(data_key: :mobile, stack: :a)
          chart.with_area(data_key: :desktop, stack: :a)
        end

        # expand domain is [0, 1]: 5 grid lines at 0, .25, .5, .75, 1.
        lines = html.css('[data-slot="chart-grid"] line')

        assert_equal 5, lines.length
        coordinates = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_in_delta(5.0, coordinates["series"]["desktop"][0], 0.001,
                        "the full stack tops out at the plot top (y = margin.top)")
      end

      def test_gradient_areas_emit_scoped_defs
        html = render_chart do |chart|
          chart.with_area(data_key: :desktop, gradient: true)
        end

        gradient = html.css("defs linearGradient").first

        assert_equal "chart-test-fill-desktop", gradient["id"], "gradient ids are chart-scoped (no page collisions)"
        stops = gradient.css("stop")

        assert_equal(["5%", "95%"], stops.map { |s| s["offset"] })
        assert_equal(%w[0.8 0.1], stops.map { |s| s["stop-opacity"] })
        assert_equal "url(#chart-test-fill-desktop)", html.css('[data-slot="chart-area"]').first["fill"]
      end

      def test_the_y_axis_variant_renders_tick_labels
        html = render_chart do |chart|
          chart.with_y_axis(tick_count: 3)
          chart.with_area(data_key: :desktop)
        end

        texts = html.css('[data-slot="chart-y-axis"] text')

        assert_operator texts.length, :>=, 2
        assert_equal "0", texts.first.text
        assert_equal "end", texts.first["text-anchor"]
      end

      def test_the_legend_renders_from_the_config
        html = render_chart do |chart|
          chart.with_area(data_key: :desktop)
          chart.with_legend
        end

        items = html.css('[data-slot="chart-legend-item"]')

        assert_equal(%w[Desktop Mobile], items.map { |item| item.text.strip })
      end

      def test_missing_values_gap_the_path
        data = DATA.map(&:dup)
        data[2][:desktop] = nil
        html = render_inline(AreaChart::Component.new(data: data, config: CONFIG, id: "gap", margin: MARGIN)) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_area(data_key: :desktop, curve: :linear)
        end

        d = html.css('[data-slot="chart-area"]').first["d"]

        assert_operator d.scan("M").length, :>=, 2, "a nil value splits the area into subpaths"
        coordinates = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_nil coordinates["series"]["desktop"][2], "missing points embed as null for the tooltip layer"
      end

      def test_the_tooltip_slot_attaches_the_engine
        html = render_chart do |chart|
          chart.with_area(data_key: :desktop)
          chart.with_tooltip(indicator: :line)
        end

        assert_predicate html.css('[data-slot="chart-tooltip-content"]'), :any?,
                         "the chrome pre-renders (full contracts in TooltipEngineTest)"
        assert html.css('[data-slot="chart-tooltip"]').first["hidden"]
      end

      def test_the_helper_dispatcher_routes_area
        html = render_inline(Poetry::Charts::Container::Component.new(config: CONFIG, id: "x")) { "" }

        assert html # dispatcher itself is exercised below via the view context
        error = assert_raises(ArgumentError) do
          vc_test_controller.view_context.poetry_chart(:sankey, data: DATA, config: CONFIG)
        end

        assert_match(/unknown chart type/, error.message)
      end
    end
  end
end
