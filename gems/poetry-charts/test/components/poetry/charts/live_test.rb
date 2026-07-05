# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Phase B-W2: the live-mode option surface. live: true embeds the
    # {spec, frame} payload (spec = the FROZEN v1 the adapter door speaks,
    # frame = the private geometry envelope); lambdas and labels raise
    # teaching errors; live: false leaves the markup untouched.
    class LiveTest < ViewComponent::TestCase
      DATA = [
        { month: "January", desktop: 186, mobile: 80 },
        { month: "February", desktop: 305, mobile: 200 },
        { month: "March", desktop: 237, mobile: 120 }
      ].freeze

      CONFIG = {
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      def payload(html)
        script = html.css('script[data-slot="chart-live-payload"]').first

        assert script, "the live payload script is embedded"
        JSON.parse(script.text)
      end

      def test_live_embeds_the_frozen_spec_plus_the_frame_envelope
        html = render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                                      live: true, margin: { left: 12, right: 12 })) do |chart|
          chart.with_grid
          chart.with_x_axis(data_key: :month)
          chart.with_area(data_key: :mobile, stack: :a)
          chart.with_area(data_key: :desktop, stack: :a)
        end

        parsed = payload(html)

        assert_equal 1, parsed["version"]
        spec = parsed["spec"]

        assert_equal 1, spec["version"]
        assert_equal "area", spec["type"]
        assert_equal(%w[mobile desktop], spec["series"].map { |s| s["key"] })
        assert_equal(%w[a a], spec["series"].map { |s| s["stack"] })
        assert_equal "month", spec.dig("axes", "x", "dataKey")
        assert_equal 3, spec["data"].length

        frame = parsed["frame"]

        assert_equal 640, frame["width"]
        assert_equal({ "top" => 5, "right" => 12, "bottom" => 5, "left" => 12 }, frame["margin"])
        assert_equal "vertical", frame["layout"]
        assert_equal "point", frame["xScaleType"]
        assert frame["categoryAxis"]
        assert_equal 5, frame["yTickCount"]
      end

      def test_bar_frame_carries_the_slot_and_radius_knobs
        html = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                                     live: true)) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :desktop, radius: [4, 4, 0, 0])
        end

        frame = payload(html)["frame"]

        assert_equal "band", frame["xScaleType"]
        assert_equal 4, frame["barGap"]
        assert_equal "10%", frame["barCategoryGap"]
        assert_equal [4, 4, 0, 0], frame.dig("series", "desktop", "radius")
      end

      def test_horizontal_bar_speaks_through_the_y_axis
        html = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                                     live: true, orientation: :horizontal)) do |chart|
          chart.with_y_axis(data_key: :month)
          chart.with_bar(data_key: :desktop)
        end

        parsed = payload(html)

        assert_equal "month", parsed.dig("spec", "axes", "y", "dataKey")
        assert_equal "horizontal", parsed.dig("frame", "layout")
      end

      def test_without_live_nothing_is_embedded
        html = render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "lv")) do |chart|
          chart.with_line(data_key: :desktop)
        end

        assert_empty html.css('script[data-slot="chart-live-payload"]')
      end

      def test_lambdas_and_labels_raise_teaching_errors
        error = assert_raises(ArgumentError) do
          render_inline(LineChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                                 live: true)) do |chart|
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_line(data_key: :desktop)
          end
        end

        assert_match(/pre-format the category strings/, error.message)

        error = assert_raises(ArgumentError) do
          render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                                live: true)) do |chart|
            chart.with_x_axis(data_key: :month)
            chart.with_bar(data_key: :desktop, labels: true)
          end
        end

        assert_match(/do not support labels/, error.message)
      end
    end
  end
end
