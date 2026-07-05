# frozen_string_literal: true

module Poetry
  module Charts
    module PieChart
      # The pie family, mirroring the shadcn blocks: simple, donut,
      # donut-with-center-text, label-list (names inside slices), legend,
      # stacked (two nested rings), and the popped active slice.
      class Preview < Poetry::Core::Preview::Base
        CONFIG = {
          visitors: { label: "Visitors" },
          chrome: { label: "Chrome", color: "var(--chart-1)" },
          safari: { label: "Safari", color: "var(--chart-2)" },
          firefox: { label: "Firefox", color: "var(--chart-3)" },
          edge: { label: "Edge", color: "var(--chart-4)" },
          other: { label: "Other", color: "var(--chart-5)" }
        }.freeze

        DATA = [
          { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
          { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
          { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
          { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
          { browser: "other", visitors: 90, fill: "var(--color-other)" }
        ].freeze

        # The stacked block's second ring: desktop vs mobile by month.
        MONTH_DATA = [
          { month: "january", desktop: 186, fill: "var(--color-january)" },
          { month: "february", desktop: 305, fill: "var(--color-february)" },
          { month: "march", desktop: 237, fill: "var(--color-march)" }
        ].freeze

        STACKED_CONFIG = CONFIG.merge(
          desktop: { label: "Desktop" },
          january: { label: "January", color: "var(--chart-1)" },
          february: { label: "February", color: "var(--chart-2)" },
          march: { label: "March", color: "var(--chart-3)" }
        ).freeze

        def simple
          render_component(data: DATA, config: CONFIG, id: "pie-simple") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser)
            chart.with_tooltip
          end
        end

        def donut
          render_component(data: DATA, config: CONFIG, id: "pie-donut") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60)
            chart.with_tooltip
          end
        end

        def donut_text
          render_component(data: DATA, config: CONFIG, id: "pie-donut-text") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60, stroke_width: 5)
            chart.with_center_label(title: "925", subtitle: "Visitors")
          end
        end

        def label_list
          render_component(data: DATA, config: CONFIG, id: "pie-label-list") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser, labels: :list, label_key: :browser)
          end
        end

        def legend
          render_component(data: DATA, config: CONFIG, id: "pie-legend") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser)
            chart.with_legend
          end
        end

        def stacked
          render_component(config: STACKED_CONFIG, id: "pie-stacked") do |chart|
            chart.with_pie(data: DATA, data_key: :visitors, name_key: :browser, outer_radius: 60)
            chart.with_pie(data: MONTH_DATA, data_key: :desktop, name_key: :month,
                           inner_radius: 70, outer_radius: 90)
          end
        end

        def donut_active
          render_component(data: DATA, config: CONFIG, id: "pie-donut-active") do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser, inner_radius: 60, active_index: 0)
          end
        end
      end
    end
  end
end
