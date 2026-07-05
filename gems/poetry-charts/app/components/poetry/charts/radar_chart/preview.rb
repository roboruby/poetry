# frozen_string_literal: true

module Poetry
  module Charts
    module RadarChart
      # The radar family, mirroring the shadcn blocks: default, dots,
      # lines-only, multiple series, circle grid, tinted grid disc,
      # gridless, and legend.
      class Preview < Poetry::Core::Preview::Base
        DATA = AreaChart::Preview::DATA
        ONE = AreaChart::Preview::ONE
        TWO = AreaChart::Preview::TWO

        def default
          simple(id: "radar-default") { |chart| chart.with_tooltip(indicator: :line) }
        end

        def dots
          simple(id: "radar-dots", dots: true)
        end

        def lines_only
          render_component(data: DATA, config: ONE, id: "radar-lines-only") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop, fill_opacity: 0, stroke_width: 2)
          end
        end

        def multiple
          render_component(data: DATA, config: TWO, id: "radar-multiple") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop)
            chart.with_radar(data_key: :mobile)
          end
        end

        def grid_circle
          simple(id: "radar-grid-circle", grid_type: :circle)
        end

        def grid_fill
          render_component(data: DATA, config: ONE, id: "radar-grid-fill") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid(fill: :desktop)
            chart.with_radar(data_key: :desktop)
          end
        end

        def grid_none
          render_component(data: DATA, config: ONE, id: "radar-grid-none") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_radar(data_key: :desktop)
          end
        end

        def legend
          render_component(data: DATA, config: TWO, id: "radar-legend") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop)
            chart.with_radar(data_key: :mobile)
            chart.with_legend
          end
        end

        private

        def simple(id:, dots: false, grid_type: :polygon)
          render_component(data: DATA, config: ONE, id: id) do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid(type: grid_type)
            chart.with_radar(data_key: :desktop, dots: dots)
            yield chart if block_given?
          end
        end
      end
    end
  end
end
