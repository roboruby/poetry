# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The radial family render contracts - rings per row with
    # value-proportional sweeps, muted track backgrounds, angle-stacked
    # gauge segments, tangent-circle corner rounding, grid discs, and the
    # ring-anchored polar tooltip payload.
    class RadialBarChartTest < ViewComponent::TestCase
      CONFIG = {
        visitors: { label: "Visitors" },
        chrome: { label: "Chrome", color: "var(--chart-1)" },
        safari: { label: "Safari", color: "var(--chart-2)" },
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      DATA = [
        { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
        { browser: "safari", visitors: 200, fill: "var(--color-safari)" }
      ].freeze

      def render_radial(data: DATA, **, &)
        render_inline(RadialBarChart::Component.new(data: data, config: CONFIG, id: "r",
                                                    name_key: :browser, inner_radius: 30,
                                                    outer_radius: 110, **), &)
      end

      def test_rings_sweep_proportionally_to_their_values
        html = render_radial { |chart| chart.with_radial_bar(data_key: :visitors) }

        bars = html.css('[data-slot="chart-radial-bar"]')

        assert_equal 2, bars.length
        assert_equal "var(--color-chrome)", bars.first["fill"]
        # nice domain [0, 280]: chrome 275 -> 353.6 degrees (nearly full),
        # safari 200 -> 257.1 - the larger sweep engages the large-arc flag.
        assert_includes bars.first["d"], ",1,0,", "chrome's near-full sweep uses the large arc"
      end

      def test_backgrounds_draw_the_muted_track_ring
        html = render_radial { |chart| chart.with_radial_bar(data_key: :visitors, background: true) }

        tracks = html.css('[data-slot="chart-radial-background"]')

        assert_equal 2, tracks.length
        assert_includes tracks.first["class"], "cn-chart-radial-track"
      end

      def test_corner_radius_rounds_the_arc_ends_with_tangent_circles
        html = render_radial(data: [{ browser: "safari", visitors: 200, fill: "var(--color-safari)" }],
                             start_angle: 0, end_angle: 250,
                             inner_radius: 80, outer_radius: 90) do |chart|
          chart.with_radial_bar(data_key: :visitors, corner_radius: 10)
        end

        d = html.css('[data-slot="chart-radial-bar"]').first["d"]

        # The radius band trims 10% each side (rings 81..89, thickness 8),
        # so the corner clamps to 4: four corner arcs + two ring arcs.
        assert_equal 6, d.scan("A").length
        assert_includes d, "A4,4,0,0,0,"
        assert_includes d, "A89,89,0,", "the outer ring arc rides the trimmed radius"
      end

      def test_stacked_segments_continue_along_the_angle
        data = [{ month: "january", desktop: 1260, mobile: 570 }]
        html = render_inline(RadialBarChart::Component.new(data: data, config: CONFIG, id: "s",
                                                           name_key: :month, end_angle: 180,
                                                           inner_radius: 80, outer_radius: 110,
                                                           max_value: 1830)) do |chart|
          chart.with_radial_bar(data_key: :mobile, stack: :a)
          chart.with_radial_bar(data_key: :desktop, stack: :a)
        end

        mobile = html.css('[data-slot="chart-radial-bar"][data-key="mobile"]').first["d"]
        desktop = html.css('[data-slot="chart-radial-bar"][data-key="desktop"]').first["d"]

        # mobile sweeps 570/1830 of 180deg from 3 o'clock; desktop continues
        # from mobile's end and finishes at 180 (9 o'clock). The band trims
        # 10% each side: ring 83..107, so the edges sit at cx +/- 107.
        assert mobile.start_with?("M232,"), "mobile starts at the 3 o'clock outer edge (cx 125 + 107)"
        assert_includes desktop, "18,125", "desktop's outer arc ends at 9 o'clock (cx 125 - 107)"
      end

      def test_grid_discs_take_their_fill_tokens
        html = render_radial(data: [{ browser: "safari", visitors: 200, fill: "var(--color-safari)" }],
                             end_angle: 100, inner_radius: 65, outer_radius: 95) do |chart|
          chart.with_polar_grid(radii: [86, 74], fills: %i[muted background])
          chart.with_radial_bar(data_key: :visitors, background: true)
        end

        circles = html.css('[data-slot="chart-polar-grid"] circle')

        assert_equal(%w[86 74], circles.map { |c| c["r"] })
        assert_includes circles.first["class"], "cn-chart-radial-disc-muted"
        assert_includes circles.last["class"], "cn-chart-radial-disc-background"
      end

      def test_auto_grid_circles_ride_the_ring_centerlines
        html = render_radial do |chart|
          chart.with_polar_grid
          chart.with_radial_bar(data_key: :visitors)
        end

        circles = html.css('[data-slot="chart-polar-grid"] circle')

        # Each circle continues a bar's track through the uncovered wedge
        # (recharts' radius band ticks): 2 rings over [30, 110] center at
        # 50 and 90.
        assert_equal %w[50 90], circles.map { |c| c["r"] }, "centerlines for 2 rings over [30, 110]"
        assert_includes circles.first["class"], "cn-chart-polar-grid-circle"
      end

      def test_polar_grid_spokes_sit_at_the_value_ticks
        html = render_radial do |chart|
          chart.with_polar_grid
          chart.with_radial_bar(data_key: :visitors)
        end

        spokes = html.css('[data-slot="chart-polar-grid"] line')

        # d3.ticks over [0, dataMax] (count 10) - the faint value spokes
        # recharts' implicit angle axis draws; explicit radial_lines: false
        # (the gauge blocks) removes them.
        assert_operator spokes.length, :>, 2
        bare = render_radial do |chart|
          chart.with_polar_grid(radial_lines: false)
          chart.with_radial_bar(data_key: :visitors)
        end

        assert_empty bare.css('[data-slot="chart-polar-grid"] line')
      end

      def test_inside_start_labels_rotate_along_the_arc
        html = render_radial(start_angle: -90, end_angle: 380) do |chart|
          chart.with_radial_bar(data_key: :visitors, labels: :inside_start, label_key: :browser)
        end

        labels = html.css('[data-slot="chart-labels"] text')

        assert_equal %w[chrome safari], labels.map(&:text)
        assert_includes labels.first["class"], "cn-chart-radial-inside-label"
        assert_includes labels.first["transform"], "rotate("
      end

      def test_the_center_label_and_ring_anchored_tooltip
        html = render_radial do |chart|
          chart.with_radial_bar(data_key: :visitors, background: true)
          chart.with_center_label(title: "475", subtitle: "Visitors")
          chart.with_tooltip
        end

        assert_equal %w[475 Visitors], html.css('[data-slot="chart-center-label"] tspan').map(&:text)
        payload = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_equal "polar", payload["layout"]
        assert_equal %w[Chrome Safari], payload["names"]
        assert_equal %w[275 200], payload["values"]["visitors"]
        assert_equal 2, payload["anchors"].length
        assert_includes html.css('[data-slot="chart-svg"]').first["data-action"],
                        "pointerover->poetry--charts--tooltip#enter"
      end

      def test_the_dispatcher_routes_radial
        html = vc_test_controller.view_context.poetry_chart(:radial, data: DATA, config: CONFIG,
                                                                     id: "via", name_key: :browser) do |chart|
          chart.with_radial_bar(data_key: :visitors)
        end

        assert_includes html, "chart-radial-bar"
      end
    end
  end
end
