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
      end

      module ClassMethods
        def live_option
          option :live, :boolean, default: false
        end
      end

      def live?
        !!live
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
