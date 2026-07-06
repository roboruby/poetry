# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # N10 W7: the radar family render contracts - categories clockwise from
    # 12 o'clock, value-proportional polygon vertices, the grid variants,
    # rim labels anchored by side, vertex dots, and the transparent hit
    # wedges driving the multi-series tooltip.
    class RadarChartTest < ViewComponent::TestCase
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

      def render_radar(**, &)
        render_inline(RadarChart::Component.new(data: DATA, config: CONFIG, id: "r", **), &)
      end

      def basic(**radar_options)
        render_radar do |chart|
          chart.with_angle_axis(data_key: :month)
          chart.with_grid
          chart.with_radar(data_key: :desktop, **radar_options)
        end
      end

      def test_the_polygon_starts_at_twelve_oclock_and_closes
        html = basic

        d = html.css('[data-slot="chart-radar"]').first["d"]

        # First vertex: angle 90 (straight up), radius 186/320 of the
        # nice-rounded domain over 96px -> cy 125 - 55.8 = 69.2 at cx 125.
        assert d.start_with?("M125,69.2"), "January sits straight above center (clockwise start)"
        assert d.end_with?("Z"), "radar polygons close"
        assert_equal 5, d.scan("L").length, "six vertices, five line segments"
        assert_equal "0.6", html.css('[data-slot="chart-radar"]').first["fill-opacity"]
      end

      def test_grid_polygons_sit_at_the_nice_radius_ticks
        html = basic

        grid_paths = html.css('[data-slot="chart-polar-grid"] path')

        # nice [0, 305] at 5 -> [0, 80, 160, 240, 320]: four nonzero rings.
        assert_equal 4, grid_paths.length
        assert_includes grid_paths.first["class"], "cn-chart-polar-grid-line"
        lines = html.css('[data-slot="chart-polar-grid"] line')

        assert_equal DATA.length, lines.length, "one radial spoke per category"
      end

      def test_the_circle_grid_swaps_polygons_for_circles
        html = render_radar do |chart|
          chart.with_angle_axis(data_key: :month)
          chart.with_grid(type: :circle)
          chart.with_radar(data_key: :desktop)
        end

        assert_equal 4, html.css('[data-slot="chart-polar-grid"] circle').length
        assert_empty html.css('[data-slot="chart-polar-grid"] path')
      end

      def test_the_tinted_grid_fills_every_ring
        html = render_radar do |chart|
          chart.with_angle_axis(data_key: :month)
          chart.with_grid(fill: :desktop)
          chart.with_radar(data_key: :desktop)
        end

        filled = html.css('[data-slot="chart-polar-grid"] path[style]')

        # Every ring tints and the overlaps compound toward the center
        # (upstream fills the whole PolarGrid). Inline style, because the
        # grid class's fill-none would beat a fill attribute.
        assert_equal 4, filled.length, "all four rings take the tint"
        assert_includes filled.first["style"], "fill: var(--color-desktop)"
        assert_equal ["0.2"], filled.map { |p| p["fill-opacity"] }.uniq
        # The fills paint AFTER the linework so the strokes wash out
        # (the fill discs carry stroke-none; the ring outlines don't).
        assert_includes filled.first["class"], "stroke-none"
        grid_children = html.css('[data-slot="chart-polar-grid"] > *').to_a
        first_fill = grid_children.index(filled.first)
        last_line = grid_children.rindex { |n| n["class"].to_s.include?("cn-chart-polar-grid-line") }

        assert_operator first_fill, :>, last_line, "tinted fills render after all linework"
      end

      def test_lines_only_radars_stroke_without_fill
        html = basic(fill_opacity: 0, stroke_width: 2)

        radar = html.css('[data-slot="chart-radar"]').first

        assert_equal "0", radar["fill-opacity"]
        assert_equal "var(--color-desktop)", radar["stroke"]
        assert_equal "2", radar["stroke-width"]
      end

      def test_dots_mark_every_vertex
        html = basic(dots: true)

        dots = html.css('[data-slot="chart-dot"]')

        assert_equal DATA.length, dots.length
        assert_equal "4", dots.first["r"]
      end

      def test_rim_labels_anchor_by_side
        html = basic

        labels = html.css('[data-slot="chart-angle-axis"] text')

        assert_equal DATA.map { |d| d[:month] }, labels.map(&:text)
        assert_equal "middle", labels[0]["text-anchor"], "12 o'clock centers"
        assert_equal "start", labels[1]["text-anchor"], "the right side leads"
        assert_equal "end", labels[4]["text-anchor"], "the left side trails"
      end

      def test_hit_wedges_drive_the_multi_series_tooltip
        html = render_radar do |chart|
          chart.with_angle_axis(data_key: :month)
          chart.with_radar(data_key: :desktop)
          chart.with_radar(data_key: :mobile)
          chart.with_tooltip(indicator: :line)
        end

        wedges = html.css('[data-slot="chart-hit-wedges"] path')

        assert_equal DATA.length, wedges.length
        assert_equal "transparent", wedges.first["fill"], "transparent stays hit-testable (none would not)"
        assert_equal "0", wedges.first["data-index"]

        payload = JSON.parse(html.css('[data-slot="chart-coordinates"]').first.text)

        assert_equal "polar", payload["layout"]
        assert_nil payload["names"], "multi-series chrome keeps its per-series rows (no retint)"
        assert_equal %w[186 305 237 73 209 214], payload["values"]["desktop"]
        rows = html.css('[data-slot="chart-tooltip-item"]')

        assert_equal(%w[desktop mobile], rows.map { |row| row["data-key"] })
        assert_predicate html.css('[data-slot="chart-tooltip-label"]'), :any?, "radar tooltips keep the category label"
      end

      def test_the_dispatcher_routes_radar
        html = vc_test_controller.view_context.poetry_chart(:radar, data: DATA, config: CONFIG, id: "via") do |chart|
          chart.with_angle_axis(data_key: :month)
          chart.with_radar(data_key: :desktop)
        end

        assert_includes html, "chart-radar"
      end
    end
  end
end
