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

      # Every chart with a tooltip can join a sync group (C-W4, recharts
      # syncId): charts sharing a sync: broadcast/receive the active index.
      #
      # The wiring is declared, not hand-built: the frame carries the
      # controller + sync value, the SVG carries the target and the
      # pointer/keyboard actions (the accessibilityLayer floor), and the
      # coordinates <script> is the data target the controller reads.
      # Full-string identifier - :tooltip is ambiguous with core's.
      def self.included(base)
        base.option :sync, :string

        base.use_stimulus do
          on :frame do
            controller CONTROLLER, if: :tooltip? do
              register
              value :sync, if: -> { sync.present? }
            end
          end
          on :svg do
            controller CONTROLLER, if: :tooltip? do
              target :svg
              action :move, on: :pointermove
              action :leave, on: :pointerleave
              action :focus, on: :focus
              action :blur, on: :blur
              action :keydown, on: :keydown
            end
          end
          on :coordinates do
            controller CONTROLLER, if: :tooltip? do
              target :data
            end
          end
          # Rendered BY the TooltipLayer child inside the frame - mirrored
          # here so the family's contract owns its full anatomy (the gate
          # flags phantom if the layer ever stops rendering it).
          on :tooltip_layer do
            controller CONTROLLER, if: :tooltip? do
              target :tooltip
            end
          end
        end
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

      # Attributes for the frame div (display: contents) wrapping svg +
      # chrome + coordinates: the declared frame wiring - tooltip
      # registration + sync here, whichever of motion/live/window the
      # family mixes in declared by those modules - plus the
      # self-identification: the frame is the chart type's own root (the
      # Container wrapper self-ids as "container", so without this the
      # SVG anatomy would have no owner in the part contract).
      def frame_attributes
        { "data-component" => self.class.component_title }.merge(stimulus_attributes_for(:frame))
      end

      # role=img for static charts; the accessibilityLayer contract when
      # the tooltip attaches (recharts: role=application + focusable).
      # Motion (Phase A) rides the same tag: data-animate + the
      # --poetry-motion-* knobs.
      def svg_interaction_attributes
        base = tooltip? ? { "role" => "application", "tabindex" => "0" } : { "role" => "img" }
        base.merge!(stimulus_attributes_for(:svg))
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
