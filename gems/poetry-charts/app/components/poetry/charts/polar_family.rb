# frozen_string_literal: true

module Poetry
  module Charts
    # The polar family chassis (pie/radar/radial): the shared margin +
    # plot/center geometry, and the per-sector pointer hit - polar marks
    # are hit by pointerover on the marked sector/wedge, not bisect, so
    # the svg gains the enter action after TooltipWiring's pointer/
    # keyboard set (include order is emission order - include this after
    # TooltipWiring).
    #
    # @example Adding the polar chassis to a family
    #   class GaugeChart::Component < Poetry::Core::Component
    #     include Poetry::Charts::ChartFamily
    #     include Poetry::Charts::TooltipWiring
    #     include Poetry::Charts::PolarFamily
    #     include Poetry::Charts::PolarFamily::SingleSeriesTooltip
    #   end
    module PolarFamily
      # The default polar margin - a slim, even inset on all sides.
      MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze

      def self.included(base)
        base.use_stimulus do
          on :svg do
            controller(TooltipWiring::CONTROLLER, if: :tooltip?) { action :enter, on: :pointerover }
          end
        end
      end

      # The margin-inset plot rect the polar geometry centers in.
      # @api private
      def plot
        @plot ||= begin
          m = MARGIN.merge((margin || {}).to_h.symbolize_keys)
          { left: m[:left].to_f, top: m[:top].to_f,
            width: width - m[:left] - m[:right], height: height - m[:top] - m[:bottom] }
        end
      end

      # The polar center's x coordinate.
      # @api private
      def cx = plot[:left] + (plot[:width] / 2.0)
      # The polar center's y coordinate.
      # @api private
      def cy = plot[:top] + (plot[:height] / 2.0)

      # The single-series polar tooltip (pie/radial): the FIRST series
      # drives the chrome, and per-index names/colors retint the one row.
      # Families supply polar_items (the sector geometry), polar_anchor
      # (where the tooltip anchors on one item), and polar_value_rows (the
      # rows the values read from). Radar keeps TooltipWiring's
      # multi-series chrome and its own payload, so it includes
      # PolarFamily alone.
      module SingleSeriesTooltip
        # The embedded per-sector geometry payload the tooltip controller
        # reads: polar layout, anchors, and per-index names/colors/values.
        # @api private
        def coordinates_json
          entry = series_entries.first
          return "{}" unless entry

          items = polar_items(entry)
          {
            "layout" => "polar",
            "categories" => items.map { |s| chart_config.label_for(s.name, s.name) },
            "names" => items.map { |s| chart_config.label_for(s.name, s.name) },
            "colors" => items.map(&:fill),
            "anchors" => items.map { |s| polar_anchor(s).map { |v| v.round(2) } },
            "values" => { entry.data_key => polar_value_rows(entry).map do |row|
              Poetry::Charts.display_value(row[entry.data_key])
            end }
          }.to_json
        end

        # The TooltipLayer child scoped to the first series, label hidden
        # by default (the per-index name carries it).
        # @api private
        def tooltip_layer_component
          TooltipLayer::Component.new(
            config: chart_config,
            series_keys: [series_entries.first&.data_key].compact,
            indicator: tooltip_config.fetch(:indicator, :dot),
            hide_label: tooltip_config.fetch(:hide_label, true),
            hide_indicator: tooltip_config.fetch(:hide_indicator, false)
          )
        end

        private :coordinates_json, :tooltip_layer_component
      end

      private :plot, :cx, :cy
    end
  end
end
