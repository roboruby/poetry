# frozen_string_literal: true

module Poetry
  module Charts
    module BarChart
      # The bar family (vertical), mirroring the shadcn blocks: default
      # (radius 8), multiple, stacked (outer-edge radius arrays), negative
      # (sign-colored cells + month labels), value labels, and the active
      # highlight. Horizontal + mixed are W4b.
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
      end
    end
  end
end
