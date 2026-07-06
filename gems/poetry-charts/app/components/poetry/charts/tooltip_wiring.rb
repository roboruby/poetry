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

      # Every chart with a tooltip can join a sync group (C-W4, recharts
      # syncId): charts sharing a sync: broadcast/receive the active index.
      def self.included(base)
        base.option :sync, :string
      end

      def tooltip_config
        tooltip?
        @tooltip_config || {}
      end

      # The legend slot's options, guarded: toggle needs the live renderer
      # (hiding a series recomputes the domain client-side).
      def legend_config
        legend?
        config = @legend_config || {}
        if config[:toggle] && !(respond_to?(:live?) && live?)
          raise ArgumentError, "with_legend toggle: true needs live: true - " \
                               "the toggle recomputes the domain client-side"
        end
        config
      end

      LEGEND_OPTIONS = %i[align items hide_icon toggle].freeze

      def legend_component
        LegendContent::Component.new(config: chart_config, **legend_config.slice(*LEGEND_OPTIONS))
      end

      # The hover cursor (recharts Tooltip cursor, default on): bars get a
      # translucent band rect, line/area/composed a vertical rule - hidden
      # until the tooltip controller positions it at the active index.
      # Renders UNDER the series (after the grid), recharts' paint order.
      def cursor_svg(kind)
        return unless tooltip? && tooltip_config.fetch(:cursor, true)

        case kind
        when :band
          if respond_to?(:horizontal?) && horizontal?
            tag.rect("data-slot": "chart-cursor", "aria-hidden": true, class: css(:cursor_band),
                     x: fnum(cartesian.plot_left), y: 0,
                     width: fnum(cartesian.plot_right - cartesian.plot_left), height: 0,
                     display: "none")
          else
            tag.rect("data-slot": "chart-cursor", "aria-hidden": true, class: css(:cursor_band),
                     x: fnum(cartesian.plot_left), y: fnum(cartesian.plot_top),
                     width: 0, height: fnum(cartesian.plot_bottom - cartesian.plot_top),
                     display: "none")
          end
        when :line
          tag.line("data-slot": "chart-cursor", "aria-hidden": true, class: css(:cursor_line),
                   x1: 0, x2: 0, y1: fnum(cartesian.plot_top), y2: fnum(cartesian.plot_bottom),
                   display: "none")
        end
      end

      # data attributes for the frame div (display: contents) wrapping
      # svg + chrome + coordinates. The motion controller (Phase A) rides
      # the same element whenever animation is on; the live controller
      # (Phase B) joins when live: is, wired so its updated dispatch
      # re-reads the tooltip's coordinates mid-stream.
      def frame_data
        window = respond_to?(:window_features?) && window_features?
        controllers = []
        controllers << CONTROLLER if tooltip?
        controllers << Motion::CONTROLLER if respond_to?(:animate?) && animate?
        controllers << Live::CONTROLLER if respond_to?(:live?) && live?
        controllers << Live::WINDOW_CONTROLLER if window

        data = {}
        data[:controller] = controllers.join(" ") if controllers.any?
        actions = []
        if controllers.include?(Live::CONTROLLER)
          actions << "poetry-chart:update->#{Live::CONTROLLER}#receive"
          actions << "#{Live::CONTROLLER}:updated->#{CONTROLLER}#refresh" if tooltip?
        end
        data[:action] = actions.join(" ") if actions.any?
        data["#{CONTROLLER}-sync-value"] = sync if tooltip? && respond_to?(:sync) && sync.present?
        data.merge!(window_frame_data) if window
        data
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
        if respond_to?(:zoom?) && zoom?
          zoom_actions = "pointerdown->#{Live::WINDOW_CONTROLLER}#startZoom " \
                         "dblclick->#{Live::WINDOW_CONTROLLER}#reset"
          base["data-action"] = [base["data-action"], zoom_actions].compact.join(" ")
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
