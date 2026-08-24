# frozen_string_literal: true

module Poetry
  module Charts
    # Shared tooltip wiring for the chart families: the frame
    # wrapper carries the controller, the SVG carries targets/actions plus
    # the accessibilityLayer floor (focusable, role=application, arrows walk
    # categories), and the hidden chrome pre-renders per-series rows the
    # controller text-swaps - zero chart math in the browser.
    module TooltipWiring
      # Full-string controller identifier - the bare :tooltip shorthand
      # would be ambiguous with the core tooltip controller.
      CONTROLLER = "poetry--charts--tooltip"

      # The wiring is declared, not hand-built: the frame carries the
      # controller + sync value, the SVG carries the target and the
      # pointer/keyboard actions (the accessibilityLayer floor), and the
      # coordinates <script> is the data target the controller reads.
      def self.included(base)
        # Sync-group id: charts sharing the same sync: broadcast and
        # receive each other's active index.
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

      # The tooltip slot's captured options, forcing lazy slot evaluation.
      # @api private
      def tooltip_config
        tooltip?
        @tooltip_config || {}
      end

      # The legend slot's options, guarded: toggle needs the live renderer
      # (hiding a series recomputes the domain client-side).
      # @api private
      def legend_config
        legend?
        config = @legend_config || {}
        if config[:toggle] && !(respond_to?(:live?) && live?)
          raise ArgumentError, "with_legend toggle: true needs live: true - " \
                               "the toggle recomputes the domain client-side"
        end
        config
      end

      # The with_legend options forwarded to the LegendContent child.
      LEGEND_OPTIONS = %i[align items hide_icon toggle].freeze

      # The LegendContent child built from the chart's config and legend
      # options.
      # @api private
      def legend_component
        LegendContent::Component.new(config: chart_config, **legend_config.slice(*LEGEND_OPTIONS))
      end

      # The hover cursor, on by default when a tooltip attaches: bars get
      # a translucent band rect, line/area/composed a vertical rule -
      # hidden until the tooltip controller positions it at the active
      # index. Renders UNDER the series (after the grid) so marks stay
      # on top.
      # @api private
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
      # family mixes in declared by those modules - plus the part-contract
      # self-identification: the frame is the chart type's own root (the
      # Container wrapper self-ids as "container", so without this the
      # SVG anatomy would have no owner in the part contract).
      # @api private
      def frame_attributes
        { "data-component" => self.class.component_title }.merge(stimulus_attributes_for(:frame))
      end

      # role=img for static charts; when the tooltip attaches the SVG
      # becomes the focusable accessibility layer (role=application +
      # tabindex) so arrow keys walk the categories. Motion rides the
      # same tag: data-animate + the --poetry-motion-* knobs.
      # @api private
      def svg_interaction_attributes
        base = tooltip? ? { "role" => "application", "tabindex" => "0" } : { "role" => "img" }
        base.merge!(stimulus_attributes_for(:svg))
        respond_to?(:motion_svg_attributes) ? base.merge(motion_svg_attributes) : base
      end

      # The TooltipLayer child built from the chart's config and tooltip
      # options.
      # @api private
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
      # @api private
      def active_dot_markers(entry)
        cartesian.points(entry).each_with_index.filter_map do |point, i|
          next if point[:value].nan?

          { index: i, x: point[:x], y: point[:y1] }
        end
      end
    end
  end
end
