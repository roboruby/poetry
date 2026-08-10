# frozen_string_literal: true

module Poetry
  module Charts
    module AreaChart
      # The area family, mirroring the shadcn blocks: default (natural),
      # linear, step, stacked, percent-stacked, gradient, legend, and the
      # visible-axes variant. Same data as upstream (visitors by month).
      class Preview < Poetry::Core::Preview::Base
        DATA = [
          { month: "January", desktop: 186, mobile: 80 },
          { month: "February", desktop: 305, mobile: 200 },
          { month: "March", desktop: 237, mobile: 120 },
          { month: "April", desktop: 73, mobile: 190 },
          { month: "May", desktop: 209, mobile: 130 },
          { month: "June", desktop: 214, mobile: 140 }
        ].freeze

        ONE = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze
        TWO = {
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        MARGIN = { left: 12, right: 12 }.freeze

        def default
          simple_chart(id: "area-default", tooltip: true)
        end

        def linear
          simple_chart(id: "area-linear", curve: :linear)
        end

        def step
          simple_chart(id: "area-step", curve: :step)
        end

        def stacked
          two_series_chart(id: "area-stacked")
        end

        def stacked_expanded
          two_series_chart(id: "area-expand", offset: :expand)
        end

        def gradient
          two_series_chart(id: "area-gradient", gradient: true)
        end

        def legend
          two_series_chart(id: "area-legend", &:with_legend)
        end

        def axes
          two_series_chart(id: "area-axes") { |chart| chart.with_y_axis(tick_count: 3) }
        end

        # The full live-window surface in one frame (see BarChart::Preview#
        # live_window) - no tick_formatter: lambdas cannot ride the payload.
        def live_window
          render_component(data: DATA, config: ONE, id: "area-live", margin: MARGIN, live: true,
                           zoom: true, sync: "area-demo") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month)
            chart.with_area(data_key: :desktop)
            chart.with_tooltip(indicator: :line)
            chart.with_brush
          end
        end

        private

        def simple_chart(id:, curve: :natural, tooltip: false)
          render_component(data: DATA, config: ONE, id: id, margin: MARGIN) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_area(data_key: :desktop, curve: curve)
            chart.with_tooltip(indicator: :line) if tooltip
          end
        end

        def two_series_chart(id:, offset: :none, gradient: false)
          render_component(data: DATA, config: TWO, id: id, offset: offset, margin: MARGIN) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_area(data_key: :mobile, stack: :a, gradient: gradient)
            chart.with_area(data_key: :desktop, stack: :a, gradient: gradient)
            yield chart if block_given?
          end
        end
      end
    end
  end
end
