# frozen_string_literal: true

module Poetry
  module Charts
    module ComposedChart
      # The composed family: bars with a trend line, and the full
      # area + bar + line mix.
      class Preview < Poetry::Core::Preview::Base
        DATA = [
          { month: "January", visitors: 320, revenue: 214, trend: 240 },
          { month: "February", visitors: 410, revenue: 305, trend: 290 },
          { month: "March", visitors: 380, revenue: 237, trend: 320 },
          { month: "April", visitors: 250, revenue: 173, trend: 300 },
          { month: "May", visitors: 445, revenue: 209, trend: 340 },
          { month: "June", visitors: 480, revenue: 264, trend: 390 }
        ].freeze

        CONFIG = {
          visitors: { label: "Visitors", color: "var(--chart-1)" },
          revenue: { label: "Revenue", color: "var(--chart-2)" },
          trend: { label: "Trend", color: "var(--chart-3)" }
        }.freeze

        def bars_with_trend
          render_component(data: DATA, config: CONFIG, id: "composed-trend") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :visitors, radius: 4)
            chart.with_line(data_key: :trend, stroke_width: 2, dots: true)
            chart.with_tooltip
          end
        end

        def full_mix
          render_component(data: DATA, config: CONFIG, id: "composed-mix") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_area(data_key: :revenue, fill_opacity: 0.25)
            chart.with_bar(data_key: :visitors, radius: [4, 4, 0, 0])
            chart.with_line(data_key: :trend, curve: :monotone_x, stroke_width: 2)
            chart.with_legend
            chart.with_tooltip
          end
        end

        # A sync group member: charts sharing sync: broadcast/receive
        # the active index - the sync value the stimulus contract holds
        # to the DOM.
        def synced
          render_component(data: DATA, config: CONFIG, id: "composed-synced",
                           sync: "composed-demo") do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_bar(data_key: :visitors, radius: 4)
            chart.with_line(data_key: :trend, stroke_width: 2, dots: true)
            chart.with_tooltip
          end
        end
      end
    end
  end
end
