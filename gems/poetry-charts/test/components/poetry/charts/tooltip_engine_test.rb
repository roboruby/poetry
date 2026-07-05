# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # N10 W5: the tooltip engine's render contracts. with_tooltip turns the
    # frame into the controller scope, the SVG into the accessibilityLayer
    # surface (role=application, focusable, actions), pre-renders the hidden
    # chrome with one row per series, embeds PRE-FORMATTED values, and
    # (lines/areas) server-renders the hidden active dots. Without the slot
    # nothing changes: role=img, zero controller wiring.
    class TooltipEngineTest < ViewComponent::TestCase
      DATA = [
        { month: "January", desktop: 186, mobile: 80 },
        { month: "February", desktop: 3050, mobile: 200 },
        { month: "March", desktop: 237, mobile: nil }
      ].freeze

      CONFIG = {
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      def render_area(tooltip: true)
        render_inline(AreaChart::Component.new(data: DATA, config: CONFIG, id: "t")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_area(data_key: :desktop)
          chart.with_area(data_key: :mobile)
          chart.with_tooltip(indicator: :line) if tooltip
        end
      end

      def test_the_frame_carries_the_controller_and_the_svg_the_accessibility_layer
        html = render_area

        frame = html.css("[data-controller='poetry--charts--tooltip']").first

        assert frame, "the frame div carries the controller"
        svg = html.css('[data-slot="chart-svg"]').first

        assert_equal "application", svg["role"], "interactive charts are applications, not images"
        assert_equal "0", svg["tabindex"]
        assert_equal "svg", svg["data-poetry--charts--tooltip-target"]
        assert_includes svg["data-action"], "pointermove->poetry--charts--tooltip#move"
        assert_includes svg["data-action"], "keydown->poetry--charts--tooltip#keydown"
      end

      def test_without_the_slot_nothing_attaches
        html = render_area(tooltip: false)

        assert_empty html.css("[data-controller]")
        assert_equal "img", html.css('[data-slot="chart-svg"]').first["role"]
        assert_empty html.css('[data-slot="chart-tooltip"]')
        assert_empty html.css('[data-slot="chart-active-dot"]')
      end

      def test_the_chrome_pre_renders_hidden_with_a_row_per_series
        html = render_area

        layer = html.css('[data-slot="chart-tooltip"]').first

        assert layer["hidden"], "the box hides until a point is active"
        assert_equal "tooltip", layer["data-poetry--charts--tooltip-target"]
        rows = layer.css('[data-slot="chart-tooltip-item"]')

        assert_equal(%w[desktop mobile], rows.map { |row| row["data-key"] })
        rows.each do |row|
          assert_predicate row.css('[data-slot="chart-tooltip-value"]'), :any?,
                           "every row keeps its value span for the controller to swap"
        end
      end

      def test_coordinates_embed_pre_formatted_values_and_the_target
        html = render_area

        script = html.css('[data-slot="chart-coordinates"]').first

        assert_equal "data", script["data-poetry--charts--tooltip-target"]
        payload = JSON.parse(script.text)

        assert_equal %w[186 3,050 237], payload["values"]["desktop"],
                     "values are pre-formatted server-side - the controller never formats"
        assert_nil payload["values"]["mobile"][2], "missing data embeds null"
      end

      def test_lines_and_areas_pre_render_hidden_active_dots
        html = render_area

        dots = html.css('[data-slot="chart-active-dot"]')

        # desktop has 3 visible points, mobile 2 (March is nil).
        assert_equal 5, dots.length
        assert(dots.all? { |dot| dot["display"] == "none" })
        assert_equal "var(--color-desktop)", dots.first["fill"]
      end

      def test_bars_wire_the_same_engine_without_dots
        html = render_inline(BarChart::Component.new(data: DATA, config: CONFIG, id: "b")) do |chart|
          chart.with_x_axis(data_key: :month)
          chart.with_bar(data_key: :desktop)
          chart.with_tooltip(hide_label: true)
        end

        assert_predicate html.css("[data-controller='poetry--charts--tooltip']"), :any?
        assert_empty html.css('[data-slot="chart-active-dot"]'), "bars reflect via data-index, not dots"
        assert_empty html.css('[data-slot="chart-tooltip-label"]'), "hide_label drops the label row"
      end
    end
  end
end
