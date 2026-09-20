# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The animation option surface + the CSS entrance hooks.
    # The contracts: data-animate + --poetry-motion-* land on the SVG with
    # the family's recharts defaults (Bar 400ms, Pie begin 400ms), each
    # family emits its entrance hook (line pathLength, area clip reveal,
    # bar origins, radar center), and animate: false restores the exact
    # pre-motion markup - the entrance must be invisible at rest.
    class MotionTest < ViewComponent::TestCase
      DATA = [
        { month: "January", desktop: 186, mobile: 80 },
        { month: "February", desktop: 305, mobile: 200 },
        { month: "March", desktop: -50, mobile: 120 }
      ].freeze

      CONFIG = {
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      def svg(html)
        html.css('[data-slot="chart-svg"]').first
      end

      def test_the_svg_carries_the_motion_knobs_with_recharts_defaults
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_area(data_key: :desktop)
        end

        assert svg(html).key?("data-animate"), "animation is on by default (recharts isAnimationActive)"
        style = svg(html)["style"]

        assert_includes style, "--poetry-motion-duration: 1500ms"
        assert_includes style, "--poetry-motion-easing: ease"
        assert_includes style, "--poetry-motion-delay: 0ms"
      end

      def test_animate_false_restores_the_exact_static_markup
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                      animate: false)) do |chart|
          chart.with_area(data_key: :desktop)
        end

        refute svg(html).key?("data-animate")
        assert_nil svg(html)["style"]
        assert_empty html.css("clipPath"), "no reveal clip when animation is off"
        refute html.css('[data-slot="chart-areas"]').first.key?("clip-path")
      end

      def test_the_knobs_are_adjustable_and_the_easing_is_guarded
        html = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                      animation_duration: 800,
                                                      animation_easing: :ease_in_out,
                                                      animation_begin: 100)) do |chart|
          chart.with_line(data_key: :desktop)
        end
        style = svg(html)["style"]

        assert_includes style, "--poetry-motion-duration: 800ms"
        assert_includes style, "--poetry-motion-easing: ease-in-out"
        assert_includes style, "--poetry-motion-delay: 100ms"

        assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                 animation_easing: :bounce)) do |chart|
            chart.with_line(data_key: :desktop)
          end
        end
      end

      def test_area_entrance_is_a_clip_path_reveal
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_area(data_key: :desktop)
        end

        rect = html.css('clipPath#chart-m-reveal rect[data-slot="chart-motion-reveal"]').first

        assert rect, "the reveal rect lives in defs"
        assert_equal %w[640 360], [rect["width"], rect["height"]], "the rect covers the full frame at rest"
        assert_equal "url(#chart-m-reveal)", html.css('[data-slot="chart-areas"]').first["clip-path"]
      end

      def test_line_entrance_normalizes_path_length_for_the_dash_draw
        html = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_line(data_key: :desktop)
        end

        assert_equal "1", html.css('[data-slot="chart-line"]').first["pathLength"]

        static = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                        animate: false)) do |chart|
          chart.with_line(data_key: :desktop)
        end

        assert_nil static.css('[data-slot="chart-line"]').first["pathLength"]
      end

      def test_bars_grow_from_the_value_baseline_by_sign_and_orientation
        vertical = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_bar(data_key: :desktop)
        end
        origins = vertical.css('[data-slot="chart-bar"]').map { |bar| bar["data-motion-origin"] }

        assert_equal %w[bottom bottom top], origins, "positive bars grow up, the negative one grows down"
        assert_includes svg(vertical)["style"], "--poetry-motion-duration: 400ms",
                        "the recharts Bar default is 400ms, not 1500"

        horizontal = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                           orientation: :horizontal)) do |chart|
          chart.with_bar(data_key: :desktop)
        end
        origins = horizontal.css('[data-slot="chart-bar"]').map { |bar| bar["data-motion-origin"] }

        assert_equal %w[left left right], origins
      end

      def test_pie_carries_the_recharts_begin_delay
        html = render_inline(PieChart::Component.new(data: [{ browser: "chrome", visitors: 275 },
                                                            { browser: "safari", visitors: 200 }],
                                                     config: { chrome: { label: "Chrome", color: "var(--chart-1)" },
                                                               safari: { label: "Safari", color: "var(--chart-2)" } },
                                                     id: "m")) do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser)
        end
        style = svg(html)["style"]

        assert svg(html).key?("data-animate")
        assert_includes style, "--poetry-motion-delay: 400ms", "recharts Pie animationBegin is 400"
      end

      def test_radar_ships_the_polar_center_for_the_rise
        html = render_inline(RadarChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_radar(data_key: :desktop)
        end

        assert_match(/--poetry-motion-center: [\d.]+px [\d.]+px/, svg(html)["style"])
      end

      # -- the motion controller wiring ------------------------------------

      PIE_DATA = [
        { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
        { browser: "safari", visitors: 200, fill: "var(--color-safari)" }
      ].freeze

      PIE_CONFIG = {
        chrome: { label: "Chrome", color: "var(--chart-1)" },
        safari: { label: "Safari", color: "var(--chart-2)" }
      }.freeze

      def test_the_motion_controller_rides_the_frame_whenever_animation_is_on
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "m")) do |chart|
          chart.with_area(data_key: :desktop)
          chart.with_tooltip
        end

        assert_equal "poetry--charts--tooltip poetry--charts--motion",
                     html.css('[data-slot="chart-svg"]').first.parent["data-controller"]

        static = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "m",
                                                        animate: false)) do |chart|
          chart.with_area(data_key: :desktop)
        end

        assert_nil static.css('[data-slot="chart-svg"]').first.parent["data-controller"]
      end

      def test_pie_sectors_embed_their_sweep_params
        html = render_inline(PieChart::Component.new(data: PIE_DATA, config: PIE_CONFIG, id: "m")) do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser)
        end

        sectors = html.css('[data-slot="chart-pie-sector"]')

        assert_equal(["pie-0"], sectors.map { |s| s["data-motion-group"] }.uniq)
        params = sectors.map { |s| s["data-motion-sector"].split.map(&:to_f) }

        # cx cy inner outer start end; two slices accumulate 0 -> 360.
        assert_equal [125, 125, 0], params.first[0, 3]
        assert_in_delta 0, params.first[4]
        assert_in_delta 208.4210, params.first[5], 0.001
        assert_in_delta 208.4210, params.last[4], 0.001
        assert_in_delta 360, params.last[5], 0.001
      end

      def test_radial_segments_embed_their_sweep_params_grouped_by_ring
        html = render_inline(RadialBarChart::Component.new(
                               data: PIE_DATA, config: PIE_CONFIG, id: "m", name_key: :browser
                             )) do |chart|
          chart.with_radial_bar(data_key: :visitors)
        end

        bars = html.css('[data-slot="chart-radial-bar"]')

        assert_equal(%w[ring-0 ring-1], bars.map { |s| s["data-motion-group"] })
        bars.each do |bar|
          assert_equal 6, bar["data-motion-sector"].split.length
        end

        static = render_inline(RadialBarChart::Component.new(
                                 data: PIE_DATA, config: PIE_CONFIG, id: "m", name_key: :browser,
                                 animate: false
                               )) do |chart|
          chart.with_radial_bar(data_key: :visitors)
        end

        assert_nil static.css('[data-slot="chart-radial-bar"]').first["data-motion-sector"]
      end
    end
  end
end
