# frozen_string_literal: true

module Poetry
  module Charts
    module BarChart
      # The bar family (vertical) across its variants: default
      # (radius 8), multiple, stacked (outer-edge radius arrays), negative
      # (sign-colored cells + month labels), value labels, the active
      # highlight, and the horizontal + mixed layouts.
      class Preview < Poetry::Core::Preview::Base
        DATA = AreaChart::Preview::DATA
        ONE = AreaChart::Preview::ONE
        TWO = AreaChart::Preview::TWO

        NEGATIVE_DATA = [
          { month: "January", visitors: 186 },
          { month: "February", visitors: 205 },
          { month: "March", visitors: -207 },
          { month: "April", visitors: 173 },
          { month: "May", visitors: -209 },
          { month: "June", visitors: 214 }
        ].freeze

        VISITORS = { visitors: { label: "Visitors" } }.freeze

        BROWSER_DATA = LineChart::Preview::BROWSER_DATA
        BROWSER_CONFIG = LineChart::Preview::BROWSER_CONFIG

        def default
          render_component(data: DATA, config: ONE, id: "bar-default") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :desktop, radius: 8)
            chart.with_tooltip(hide_label: true)
          end
        end

        def multiple
          render_component(data: DATA, config: TWO, id: "bar-multiple") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :desktop, radius: 4)
            chart.with_bar(data_key: :mobile, radius: 4)
          end
        end

        def stacked
          render_component(data: DATA, config: TWO, id: "bar-stacked") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :desktop, stack: :a, radius: [0, 0, 4, 4])
            chart.with_bar(data_key: :mobile, stack: :a, radius: [4, 4, 0, 0])
            chart.with_legend
          end
        end

        def negative
          render_component(data: NEGATIVE_DATA, config: VISITORS, id: "bar-negative") do |chart|
            chart.with_grid
            chart.with_bar(data_key: :visitors, labels: true, label_key: :month,
                           cell_fill: ->(_row, value) { value.positive? ? "var(--chart-1)" : "var(--chart-2)" })
          end
        end

        def label
          render_component(data: DATA, config: ONE, id: "bar-label", margin: { top: 20 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :desktop, radius: 8, labels: true)
          end
        end

        def active
          render_component(data: BROWSER_DATA, config: BROWSER_CONFIG, id: "bar-active") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :browser, tick_formatter: ->(v) { BROWSER_CONFIG[v.to_sym][:label] })
            chart.with_bar(data_key: :visitors, radius: 8, color_key: :fill, active_index: 2)
          end
        end

        def horizontal
          render_component(data: DATA, config: ONE, id: "bar-horizontal",
                           orientation: :horizontal, margin: { left: -20 }) do |chart|
            chart.with_y_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] }, tick_margin: 10)
            chart.with_bar(data_key: :desktop, radius: 5)
          end
        end

        def mixed
          render_component(data: BROWSER_DATA, config: BROWSER_CONFIG, id: "bar-mixed",
                           orientation: :horizontal, margin: { left: 0 }) do |chart|
            chart.with_y_axis(data_key: :browser, tick_margin: 10,
                              tick_formatter: ->(v) { BROWSER_CONFIG[v.to_sym][:label] })
            chart.with_bar(data_key: :visitors, radius: 5, color_key: :fill)
          end
        end

        # The full live-window surface in one frame - the client renderer
        # (live:), the zoom drag, the brush strip, and a sync group: the
        # wiring the stimulus contract holds to the DOM. No tick_formatter
        # (lambdas cannot ride the live payload).
        def live_window
          render_component(data: DATA, config: ONE, id: "bar-live", live: true, zoom: true,
                           sync: "bar-demo") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month)
            chart.with_bar(data_key: :desktop, radius: 8)
            chart.with_tooltip(hide_label: true)
            chart.with_brush
          end
        end
      end
    end
  end
end
