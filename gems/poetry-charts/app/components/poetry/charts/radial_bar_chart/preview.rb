# frozen_string_literal: true

module Poetry
  module Charts
    module RadialBarChart
      # The radial family, mirroring the shadcn blocks: simple (rings +
      # muted tracks), grid (disc boundaries), inside-start labels, the
      # gauge shapes (disc tracks + center text), and the angle-stacked
      # half gauge.
      class Preview < Poetry::Core::Preview::Base
        CONFIG = {
          visitors: { label: "Visitors" },
          chrome: { label: "Chrome", color: "var(--chart-1)" },
          safari: { label: "Safari", color: "var(--chart-2)" },
          firefox: { label: "Firefox", color: "var(--chart-3)" },
          edge: { label: "Edge", color: "var(--chart-4)" },
          other: { label: "Other", color: "var(--chart-5)" },
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        DATA = [
          { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
          { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
          { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
          { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
          { browser: "other", visitors: 90, fill: "var(--color-other)" }
        ].freeze

        def simple
          render_component(data: DATA, config: CONFIG, id: "radial-simple", name_key: :browser,
                           inner_radius: 30, outer_radius: 110) do |chart|
            chart.with_radial_bar(data_key: :visitors, background: true)
            chart.with_tooltip
          end
        end

        def grid
          render_component(data: DATA, config: CONFIG, id: "radial-grid", name_key: :browser,
                           inner_radius: 30, outer_radius: 100) do |chart|
            chart.with_polar_grid
            chart.with_radial_bar(data_key: :visitors)
          end
        end

        def label
          render_component(data: DATA, config: CONFIG, id: "radial-label", name_key: :browser,
                           start_angle: -90, end_angle: 380, inner_radius: 30, outer_radius: 110) do |chart|
            chart.with_radial_bar(data_key: :visitors, background: true,
                                  labels: :inside_start, label_key: :browser)
          end
        end

        def shape
          render_component(data: [{ browser: "safari", visitors: 1260, fill: "var(--color-safari)" }],
                           config: CONFIG, id: "radial-shape", name_key: :browser,
                           end_angle: 100, inner_radius: 65, outer_radius: 95) do |chart|
            chart.with_polar_grid(radii: [86, 74], fills: %i[muted background], radial_lines: false)
            chart.with_radial_bar(data_key: :visitors, background: true)
            chart.with_center_label(title: "1,260", subtitle: "Visitors")
          end
        end

        def text
          render_component(data: [{ browser: "safari", visitors: 200, fill: "var(--color-safari)" }],
                           config: CONFIG, id: "radial-text", name_key: :browser,
                           start_angle: 0, end_angle: 250, inner_radius: 80, outer_radius: 90) do |chart|
            chart.with_polar_grid(radii: [90, 80], fills: %i[muted background], radial_lines: false)
            chart.with_radial_bar(data_key: :visitors, background: true, corner_radius: 10)
            chart.with_center_label(title: "200", subtitle: "Visitors")
          end
        end

        def stacked
          data = [{ month: "january", desktop: 1260, mobile: 570 }]
          # No max_value: recharts maps the stack through [0, dataMax] over
          # the raw values (1260), so mobile fills 570/1260 = 81deg and
          # desktop stacks on and clips at the 180deg end.
          render_component(data: data, config: CONFIG, id: "radial-stacked", name_key: :month,
                           end_angle: 180, inner_radius: 80, outer_radius: 110) do |chart|
            chart.with_radial_bar(data_key: :mobile, stack: :a, corner_radius: 5)
            chart.with_radial_bar(data_key: :desktop, stack: :a, corner_radius: 5)
            chart.with_center_label(title: "1,830", subtitle: "Visitors", compact: true)
          end
        end

        # A sync group member (C-W4): the sync value the stimulus contract
        # holds to the DOM.
        def synced
          render_component(data: DATA, config: CONFIG, id: "radial-synced", name_key: :browser,
                           inner_radius: 30, outer_radius: 110, sync: "radial-demo") do |chart|
            chart.with_radial_bar(data_key: :visitors, background: true)
            chart.with_tooltip
          end
        end
      end
    end
  end
end
