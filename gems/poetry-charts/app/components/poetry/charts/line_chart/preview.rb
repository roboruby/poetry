# frozen_string_literal: true

module Poetry
  module Charts
    module LineChart
      # The line family, mirroring the shadcn blocks: default (natural),
      # linear, step, multiple series, dots, per-point dot colors, and
      # point labels. Same data as upstream.
      class Preview < Poetry::Core::Preview::Base
        DATA = AreaChart::Preview::DATA
        ONE = AreaChart::Preview::ONE
        TWO = AreaChart::Preview::TWO
        MARGIN = AreaChart::Preview::MARGIN

        BROWSER_CONFIG = {
          visitors: { label: "Visitors", color: "var(--chart-2)" },
          chrome: { label: "Chrome", color: "var(--chart-1)" },
          safari: { label: "Safari", color: "var(--chart-2)" },
          firefox: { label: "Firefox", color: "var(--chart-3)" },
          edge: { label: "Edge", color: "var(--chart-4)" },
          other: { label: "Other", color: "var(--chart-5)" }
        }.freeze

        BROWSER_DATA = [
          { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
          { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
          { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
          { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
          { browser: "other", visitors: 90, fill: "var(--color-other)" }
        ].freeze

        def default
          simple_chart(id: "line-default", tooltip: true)
        end

        def linear
          simple_chart(id: "line-linear", curve: :linear)
        end

        def step
          simple_chart(id: "line-step", curve: :step)
        end

        def multiple
          render_component(data: DATA, config: TWO, id: "line-multiple", margin: MARGIN) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_line(data_key: :desktop)
            chart.with_line(data_key: :mobile)
          end
        end

        def dots
          simple_chart(id: "line-dots", dots: true)
        end

        def dots_colors
          render_component(data: BROWSER_DATA, config: BROWSER_CONFIG, id: "line-dots-colors",
                           margin: { top: 24, left: 24, right: 24 }) do |chart|
            chart.with_grid
            chart.with_line(data_key: :visitors, dots: true, dot_radius: 5, dot_color_key: :fill)
          end
        end

        def label
          render_component(data: DATA, config: ONE, id: "line-label",
                           margin: { top: 20, left: 12, right: 12 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_line(data_key: :desktop, dots: true, labels: true)
          end
        end

        def references_and_errors
          data = AreaChart::Preview::DATA.map.with_index do |row, i|
            row.merge(err: [12 + (i * 3), 20 - i])
          end
          render_component(data: data, config: ONE, id: "line-refs",
                           margin: { left: 12, right: 12 }) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_line(data_key: :desktop, error_key: :err)
            chart.with_reference_line(y: 204, label: "avg")
            chart.with_reference_area(y1: 280, y2: 320, label: "goal")
            chart.with_tooltip
          end
        end

        private

        def simple_chart(id:, curve: :natural, dots: false, tooltip: false)
          render_component(data: DATA, config: ONE, id: id, margin: MARGIN) do |chart|
            chart.with_grid
            chart.with_x_axis(data_key: :month, tick_formatter: ->(v) { v[0, 3] })
            chart.with_line(data_key: :desktop, curve: curve, dots: dots)
            chart.with_tooltip(hide_label: true) if tooltip
          end
        end
      end
    end
  end
end
