# frozen_string_literal: true

module Poetry
  module Charts
    # Live mode: a chart that opts in with `live: true` embeds a
    # {spec, frame} payload the client renderer recomputes geometry from
    # when data changes too often to round-trip to the server. `spec` is
    # the FROZEN spec v1 built by the same Poetry::Charts::Spec the
    # adapter door uses (Door 2 stays closed); `frame` is a PRIVATE engine
    # envelope carrying the geometry-affecting knobs the spec deliberately
    # omits. Everything else about the chart stays server-rendered.
    #
    # Live charts cannot carry Ruby lambdas to the browser: tick
    # formatters and label slots raise a teaching error - format data
    # host-side (pre-formatted category strings) instead.
    module Live
      CONTROLLER = "poetry--charts--live"

      def self.included(base)
        base.extend(ClassMethods)

        # Declared after TooltipWiring's and Motion's frame wirings
        # (include order IS emission order): live registration + the host
        # update hook, the tooltip re-read on live's updated dispatch, and
        # the window controller's server-computed rects. The SVG gains the
        # zoom drag actions; the payload <script> is live's data target.
        base.use_stimulus do
          on :frame do
            controller CONTROLLER, if: :live? do
              register
              action :receive, on: "poetry-chart:update"
            end
            controller TooltipWiring::CONTROLLER, if: -> { live? && tooltip? } do
              action :refresh, on: event(CONTROLLER, :updated)
            end
            controller WINDOW_CONTROLLER, if: :window_features? do
              register
              value :zoom, from: :zoom?
              value :plot, from: :window_plot_json
              value :brush, from: :window_brush_json, if: -> { brush_config }
            end
          end
          on :svg do
            controller WINDOW_CONTROLLER, if: :zoom? do
              action :startZoom, on: :pointerdown
              action :reset, on: :dblclick
            end
          end
          on :live_payload do
            controller(CONTROLLER) { target :payload }
          end
          # Rendered by brush_svg via the stimulus_action descriptor -
          # declared so the contract owns the token (and flags drift).
          on :brush do
            controller(WINDOW_CONTROLLER, if: -> { brush_config }) do
              action :startBrush, on: :pointerdown
            end
          end
        end

        # The live-window anatomy (all server-rendered; the window
        # controller only drags and repaints) - declared here so every
        # live-capable family publishes the same styling surface.
        base.part "chart-brush", "The brush strip group (with_brush): track + window + two " \
                                 "handles below the x axis"
        base.part "chart-brush-track", "The full-width brush rail"
        base.part "chart-brush-window", "The selected-range rect the drag moves"
        base.part "chart-brush-handle", "One draggable window edge",
                  states: { "data-edge" => { condition: "always - which edge",
                                             values: %w[start end] } }
        base.part "chart-zoom-selection", "The zoom drag-selection overlay (zoom: true), " \
                                          "hidden until a drag starts"
        base.part "chart-live-payload", "The embedded {spec, frame} JSON the live renderer " \
                                        "recomputes geometry from"
      end

      module ClassMethods
        def live_option
          option :live, :boolean, default: false
          # The window features (C-W5): both slice the data client-side, so
          # both need the live renderer.
          option :zoom, :boolean, default: false
          renders_one :brush, lambda { |height: 30|
            @brush_config = { height: height.to_f }
            nil
          }
        end
      end

      def live?
        !!live
      end

      WINDOW_CONTROLLER = "poetry--charts--window"
      BRUSH_GAP = 8

      def brush_config
        brush?
        if @brush_config && !live?
          raise ArgumentError, "with_brush needs live: true - the window recomputes client-side"
        end

        @brush_config
      end

      def zoom?
        raise ArgumentError, "zoom: true needs live: true - the window recomputes client-side" if zoom && !live?

        !!zoom
      end

      def window_features?
        !!brush_config || zoom?
      end

      # The brush strip reserves space below the x axis by growing the
      # bottom margin the cartesian sees.
      def live_margin
        base = (margin || {}).to_h.symbolize_keys
        return base unless brush_config

        bottom = (base[:bottom] || Cartesian::DEFAULT_MARGIN[:bottom]).to_f
        base.merge(bottom: bottom + brush_config[:height] + BRUSH_GAP)
      end

      def brush_top
        original_bottom = (margin || {}).to_h.symbolize_keys.fetch(:bottom, Cartesian::DEFAULT_MARGIN[:bottom]).to_f
        height - original_bottom - brush_config[:height]
      end

      # The strip: track + window + two handles, all server-rendered; the
      # window controller drags them and repaints on window changes.
      def brush_svg
        config = brush_config
        return unless config

        left = cartesian.plot_left
        width = cartesian.plot_right - left
        top = brush_top
        handle = 6.0

        tag.g("data-slot": "chart-brush", "aria-hidden": true,
              "data-action": stimulus_action(:startBrush, on: :pointerdown)) do
          safe_join([
                      tag.rect(class: css(:brush_track), "data-slot": "chart-brush-track",
                               x: fnum(left), y: fnum(top), width: fnum(width),
                               height: fnum(config[:height]), rx: 4),
                      tag.rect(class: css(:brush_window), "data-slot": "chart-brush-window",
                               x: fnum(left), y: fnum(top), width: fnum(width),
                               height: fnum(config[:height]), rx: 4),
                      tag.rect(class: css(:brush_handle), "data-slot": "chart-brush-handle", "data-edge": "start",
                               x: fnum(left - (handle / 2)), y: fnum(top), width: fnum(handle),
                               height: fnum(config[:height]), rx: 2),
                      tag.rect(class: css(:brush_handle), "data-slot": "chart-brush-handle", "data-edge": "end",
                               x: fnum(left + width - (handle / 2)), y: fnum(top), width: fnum(handle),
                               height: fnum(config[:height]), rx: 2)
                    ])
        end
      end

      # The zoom drag-selection overlay (hidden until a drag starts).
      def zoom_selection_svg
        return unless zoom?

        tag.rect(class: css(:reference_area), "data-slot": "chart-zoom-selection", "aria-hidden": true,
                 x: 0, y: fnum(cartesian.plot_top), width: 0,
                 height: fnum(cartesian.plot_bottom - cartesian.plot_top),
                 "fill-opacity": 0.15, display: "none")
      end

      # Value readers for the window controller's declared frame wiring:
      # the plot rect and the brush strip rect, server-computed (the
      # controller's only layout math is fractions of these).
      def window_plot_json
        [cartesian.plot_left, cartesian.plot_right, cartesian.plot_top, cartesian.plot_bottom].to_json
      end

      def window_brush_json
        [cartesian.plot_left, brush_top, cartesian.plot_right - cartesian.plot_left,
         brush_config[:height]].to_json
      end

      def live_payload
        ensure_live_compatible!
        {
          "version" => 1,
          "spec" => live_spec.to_h,
          "frame" => live_frame
        }
      end

      def live_payload_json
        live_payload.to_json
      end

      def live_spec
        Spec.new(type: live_type, data: data, series: live_series, axes: live_axes)
      end

      # The geometry-affecting knobs shared by the cartesian trio; families
      # merge their extras (bar gaps/radii) via live_frame_extras.
      def live_frame
        {
          "width" => width,
          "height" => height,
          "margin" => Cartesian::DEFAULT_MARGIN
                      .merge((margin || {}).to_h.symbolize_keys)
                      .transform_keys(&:to_s),
          "layout" => cartesian.layout.to_s,
          "xScaleType" => live_x_scale_type.to_s,
          "categoryAxis" => live_category_axis?,
          "valueAxis" => !cartesian.horizontal? && !y_axis_config.nil?,
          "yTickCount" => cartesian.y_tick_count,
          "offset" => cartesian.offset.to_s,
          "xTickMargin" => x_axis_config&.tick_margin,
          "yTickMargin" => y_axis_config&.tick_margin
        }.merge(live_frame_extras).compact
      end

      def live_frame_extras
        {}
      end

      # Lambdas cannot ride a JSON payload - fail at render, with the fix.
      def ensure_live_compatible!
        if x_axis_config&.tick_formatter || y_axis_config&.tick_formatter
          raise ArgumentError, "live: charts cannot serialize tick_formatter lambdas - " \
                               "pre-format the category strings in your data instead"
        end
        if series_entries.any? { |entry| entry.respond_to?(:error_key) && entry.error_key }
          raise ArgumentError, "live: charts do not support error bars yet (Phase C scope) - " \
                               "drop error_key: or render without live:"
        end
        if respond_to?(:reference_marks) && reference_marks.any?
          raise ArgumentError, "live: charts do not support reference marks yet (Phase C scope)"
        end
        return unless live_labels_configured?

        raise ArgumentError, "live: charts do not support labels yet (Phase B scope) - " \
                             "drop labels: or render without live:"
      end

      def live_labels_configured?
        series_entries.any? { |entry| entry.respond_to?(:labels) && entry.labels }
      end
    end
  end
end
