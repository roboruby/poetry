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

        # Upstream draws BOTH series as strokes and turns the grid's radial
        # spokes off (PolarGrid radialLines={false}).
        def lines_only
          render_component(data: DATA, config: TWO, id: "radar-lines-only") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid(radial_lines: false)
            chart.with_radar(data_key: :desktop, fill_opacity: 0, stroke_width: 2)
            chart.with_radar(data_key: :mobile, fill_opacity: 0, stroke_width: 2)
          end
        end

        # Only the FIRST series is translucent upstream (fillOpacity 0.6);
        # the second keeps the opaque default and covers the overlap.
        def multiple
          render_component(data: DATA, config: TWO, id: "radar-multiple") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop)
            chart.with_radar(data_key: :mobile, fill_opacity: 1)
          end
        end

        def grid_circle
          simple(id: "radar-grid-circle", grid_type: :circle, dots: true)
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
            chart.with_radar(data_key: :desktop, dots: true)
          end
        end

        def legend
          render_component(data: DATA, config: TWO, id: "radar-legend") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop)
            chart.with_radar(data_key: :mobile, fill_opacity: 1)
            chart.with_legend
          end
        end

        # A sync group member: the sync value the stimulus contract
        # holds to the DOM.
        def synced
          render_component(data: DATA, config: ONE, id: "radar-synced", sync: "radar-demo") do |chart|
            chart.with_angle_axis(data_key: :month)
            chart.with_grid
            chart.with_radar(data_key: :desktop)
            chart.with_tooltip
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
