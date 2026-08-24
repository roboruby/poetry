# frozen_string_literal: true

module Poetry
  module Charts
    # The line chart family.
    module LineChart
      # Renders a line chart - one stroked curve per series, no fills -
      # through the cartesian pipeline. Adds dot variants (solid
      # series-colored dots, or per-point colors read from a data key),
      # value labels stamped above the points, and error whiskers.
      #
      # @example Two series over a formatted month axis
      #   <%= poetry_chart :line, data:, config:, margin: { left: 12, right: 12 } do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month, tick_formatter: ->(v) { v[0, 3] } %>
      #     <% c.with_line data_key: :desktop %>
      #     <% c.with_line data_key: :mobile %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live
        include Poetry::Charts::ReferenceMarks
        include Poetry::Charts::ErrorBars

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Compose from slots: with_grid / with_x_axis(data_key:) / with_line(data_key:) / with_legend.",
          "Lines default to stroke-width 2 and NO dots (the shadcn block look); dots: true adds them.",
          "dot_color_key: reads a per-row data key for per-point dot colors (the dots-colors block).",
          "labels: true stamps each value above its point; give the chart margin top when using it.",
          "Colors come from the config - never set stroke on a line directly.",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        # One with_line call's captured series config.
        Series = Data.define(:key, :curve, :stroke_width, :dots, :dot_radius, :dot_color_key, :labels,
                             :error_key, :error_width) do
          # The cartesian pipeline contract (lines never stack).
          def stack = nil
        end

        # The rows to plot: an array of hashes, one per x category.
        option :data, ActiveModel::Type::Value.new, required: true
        # The series config - key => { label:, color: } - naming and
        # coloring every series.
        option :config, ActiveModel::Type::Value.new, required: true
        # Explicit DOM id token, stable across renders; otherwise the
        # chart gets a unique per-render id.
        option :id, :string
        # ViewBox width in pixels; the rendered chart scales to its
        # container.
        option :width, :integer, default: 640
        # ViewBox height in pixels.
        option :height, :integer, default: 360
        # Plot margin overrides ({ top:, right:, bottom:, left: }),
        # merged over the defaults.
        option :margin, ActiveModel::Type::Value.new
        # Accessible name for the chart SVG; defaults to one built from
        # the configured series.
        option :label, :string

        motion_options
        live_option

        part "chart-svg", "The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; " \
                          "role=img, or the focusable role=application accessibilityLayer when the " \
                          "tooltip attaches",
             states: {
               "data-animate" => "present when animate (the default) - the motion stylesheet and " \
                                 "controller key the entrance off it",
               "data-motion" => { condition: "runtime - the motion rig stamps the animation " \
                                             "lifecycle (entrance/morph, then settled)",
                                  values: %w[entrance morph settled] }
             },
             vars: {
               "--poetry-motion-duration" => "the entrance/morph duration (animation_duration, ms)",
               "--poetry-motion-easing" => "the animation easing keyword (animation_easing)",
               "--poetry-motion-delay" => "the pre-animation hold (animation_begin, ms)"
             }
        part "chart-grid", "The gridline group (with_grid) - horizontal and/or vertical rules " \
                           "across the plot"
        part "chart-cursor", "The hover cursor, hidden until the tooltip controller positions " \
                             "and reveals it at the active index - a vertical rule or a " \
                             "translucent band rect (bar charts)"
        part "chart-lines", "The line-mark group - each series' curve plus its companion marks"
        part "chart-line", "One series' stroked curve - pathLength=1 when animating so the " \
                           "dash draw-in needs no measurement",
             states: { "data-key" => "the series key" }
        part "chart-dots", "One series' point-dot group (dots: true)",
             states: { "data-key" => "the series key" }
        part "chart-dot", "One point dot (<circle>)"
        part "chart-error-bars", "One series' error-whisker group (error_key:) - cap-stem-cap " \
                                 "paths in the foreground color",
             states: { "data-key" => "the series key" }
        part "chart-labels", "One series' value-label group (labels: true)",
             states: { "data-key" => "the series key" }
        part "chart-reference", "The reference-mark group (with_reference_line/_area/_dot), " \
                                "painted above the series"
        part "chart-active-dots", "The hover-marker group (with_tooltip) - pre-rendered hidden " \
                                  "circles for every series x index"
        part "chart-active-dot", "One hover marker - display=none until the tooltip controller " \
                                 "reveals the active index's dot",
             states: {
               "data-key" => "the series key",
               "data-index" => "the datum index",
               "data-active" => "runtime - rides the marker while its index is the active one"
             }
        part "chart-x-axis", "The x-axis tick-label group (with_x_axis)"
        part "chart-coordinates", "The embedded per-index geometry payload " \
                                  "(<script type=application/json>) the tooltip controller " \
                                  "reads - zero chart math in the browser"

        # A line series bound to data_key:. dots: marks each point;
        # dot_color_key: reads per-point dot colors from the row;
        # labels: stamps each value above its point; error_key: adds
        # error whiskers.
        renders_many :lines, lambda { |data_key:, curve: :natural, stroke_width: 2, dots: false,
                                       dot_radius: 3, dot_color_key: nil, labels: false, error_key: nil, error_width: 5|
          raise ArgumentError, "unknown curve #{curve.inspect}" unless CURVES.include?(curve.to_sym)

          (@series_entries ||= []) << Series.new(key: data_key.to_s, curve: curve.to_sym, stroke_width:,
                                                 dots:, dot_radius:, dot_color_key: dot_color_key&.to_s,
                                                 labels:, error_key: error_key&.to_s, error_width:)
          nil
        }

        include Poetry::Charts::CartesianFamily

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          lines? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        # The chart's cartesian geometry, built once per render.
        # @api private
        def cartesian
          @cartesian ||= Cartesian.new(
            data: data,
            series: series_entries,
            width: width,
            height: height,
            x_key: x_axis_config&.data_key,
            margin: live_margin,
            category_axis: x_axis?,
            value_axis: y_axis?,
            y_tick_count: y_axis_config&.tick_count || 5
          )
        end

        # One series' stroked curve path.
        # @api private
        def series_path(entry)
          points = cartesian.points(entry)
          Geometry::Line.new(
            x: ->(p, _i) { p[:x] },
            y: ->(p, _i) { p[:y1] },
            curve: entry.curve,
            defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        # The visible points for dots/labels (NaN values render nothing).
        # @api private
        def markers(entry)
          cartesian.points(entry).each_with_index.filter_map do |point, i|
            next if point[:value].nan?

            { x: point[:x], y: point[:y1], value: point[:value], row: data[i] }
          end
        end

        # Per-point dot color: the dot_color_key row value (CSS-validated),
        # else the series color.
        # @api private
        def dot_fill(entry, marker)
          if entry.dot_color_key
            color = marker[:row].to_h.transform_keys(&:to_s)[entry.dot_color_key].to_s
            raise ArgumentError, "dot color #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

            color
          else
            "var(--color-#{entry.key})"
          end
        end

        # One x tick's label, through the slot's formatter when given.
        # @api private
        def x_tick_label(category)
          formatter = x_axis_config&.tick_formatter
          formatter ? formatter.call(category).to_s : category.to_s
        end

        # One y tick's label, through the slot's formatter when given.
        # @api private
        def y_tick_label(tick)
          formatter = y_axis_config&.tick_formatter
          formatter ? formatter.call(tick).to_s : Geometry.js_number(tick.to_f)
        end

        # A point's value label, integers shown bare.
        # @api private
        def marker_label(marker)
          value = marker[:value]
          value == value.to_i ? value.to_i.to_s : value.to_s
        end

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Line chart"

        # The embedded per-index geometry payload the tooltip controller
        # reads.
        # @api private
        def coordinates_json
          cartesian.coordinates.to_json
        end

        # -- live mode ---------------------------------------------------

        # The chart type in the live spec.
        # @api private
        def live_type = :line

        # The series list serialized into the live spec.
        # @api private
        def live_series
          series_entries.map { |e| { data_key: e.key, curve: e.curve } }
        end

        # The axis config serialized into the live spec.
        # @api private
        def live_axes
          axes = {}
          axes[:x] = { data_key: x_axis_config.data_key } if x_axis_config&.data_key
          axes[:y] = { tick_count: y_axis_config.tick_count } if y_axis_config
          axes
        end

        # The x scale kind the live renderer rebuilds.
        # @api private
        def live_x_scale_type = :point
        # Whether the live frame renders a category axis.
        # @api private
        def live_category_axis? = x_axis?
      end
    end
  end
end
