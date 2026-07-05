# frozen_string_literal: true

module Poetry
  module Charts
    module ScatterChart
      # The scatter family (Phase C-W1, beyond the shadcn surface):
      # simple, two series, and z-sized bubbles.
      class Preview < Poetry::Core::Preview::Base
        SAMPLE = [
          { height: 161, weight: 51, bmi: 19.7 },
          { height: 167, weight: 59, bmi: 21.2 },
          { height: 170, weight: 68, bmi: 23.5 },
          { height: 174, weight: 66, bmi: 21.8 },
          { height: 178, weight: 79, bmi: 24.9 },
          { height: 183, weight: 84, bmi: 25.1 },
          { height: 189, weight: 95, bmi: 26.6 }
        ].freeze

        CONTROL = [
          { height: 158, weight: 62, bmi: 24.8 },
          { height: 165, weight: 71, bmi: 26.1 },
          { height: 172, weight: 60, bmi: 20.3 },
          { height: 180, weight: 88, bmi: 27.2 },
          { height: 186, weight: 77, bmi: 22.3 }
        ].freeze

        ONE = { sample: { label: "Sample", color: "var(--chart-1)" } }.freeze
        TWO = ONE.merge(control: { label: "Control", color: "var(--chart-2)" }).freeze

        def default
          render_component(data: SAMPLE, config: ONE, id: "scatter-default",
                           margin: { left: 12, right: 12 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :height, name: "Height")
            chart.with_y_axis(data_key: :weight, name: "Weight")
            chart.with_scatter(key: :sample)
            chart.with_tooltip
          end
        end

        def multiple
          render_component(data: SAMPLE, config: TWO, id: "scatter-multiple",
                           margin: { left: 12, right: 12 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :height, name: "Height")
            chart.with_y_axis(data_key: :weight, name: "Weight")
            chart.with_scatter(key: :sample)
            chart.with_scatter(key: :control, data: CONTROL)
            chart.with_legend
            chart.with_tooltip
          end
        end

        def bubbles
          render_component(data: SAMPLE, config: ONE, id: "scatter-bubbles",
                           margin: { left: 12, right: 12 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :height, name: "Height")
            chart.with_y_axis(data_key: :weight, name: "Weight")
            chart.with_z_axis(data_key: :bmi, range: [64, 400])
            chart.with_scatter(key: :sample)
            chart.with_tooltip
          end
        end
      end
    end
  end
end
