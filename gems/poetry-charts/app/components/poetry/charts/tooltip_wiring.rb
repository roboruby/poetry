# frozen_string_literal: true

module Poetry
  module Charts
    # Shared tooltip wiring for the chart families (N10 W5): the frame
    # wrapper carries the controller, the SVG carries targets/actions plus
    # the accessibilityLayer floor (focusable, role=application, arrows walk
    # categories), and the hidden chrome pre-renders per-series rows the
    # controller text-swaps - zero chart math in the browser.
    module TooltipWiring
      CONTROLLER = "poetry--charts--tooltip"

      SVG_ACTIONS = %W[
        pointermove->#{CONTROLLER}#move
        pointerleave->#{CONTROLLER}#leave
        focus->#{CONTROLLER}#focus
        blur->#{CONTROLLER}#blur
        keydown->#{CONTROLLER}#keydown
      ].join(" ").freeze

      def tooltip_config
        tooltip?
        @tooltip_config || {}
      end

      # data attributes for the frame div (display: contents) wrapping
      # svg + chrome + coordinates.
      def frame_data
        tooltip? ? { controller: CONTROLLER } : {}
      end

      # role=img for static charts; the accessibilityLayer contract when
      # the tooltip attaches (recharts: role=application + focusable).
      # Motion (Phase A) rides the same tag: data-animate + the
      # --poetry-motion-* knobs.
      def svg_interaction_attributes
        base = if tooltip?
                 {
                   "role" => "application",
                   "tabindex" => "0",
                   "data-poetry--charts--tooltip-target" => "svg",
                   "data-action" => SVG_ACTIONS
                 }
               else
                 { "role" => "img" }
               end
        respond_to?(:motion_svg_attributes) ? base.merge(motion_svg_attributes) : base
      end

      def tooltip_layer_component
        TooltipLayer::Component.new(
          config: chart_config,
          series_keys: series_entries.map(&:key),
          indicator: tooltip_config.fetch(:indicator, :dot),
          hide_label: tooltip_config.fetch(:hide_label, false),
          hide_indicator: tooltip_config.fetch(:hide_indicator, false)
        )
      end

      # The hover markers lines/areas show at the active index -
      # server-rendered hidden circles the controller toggles.
      def active_dot_markers(entry)
        cartesian.points(entry).each_with_index.filter_map do |point, i|
          next if point[:value].nan?

          { index: i, x: point[:x], y: point[:y1] }
        end
      end
    end
  end
end
