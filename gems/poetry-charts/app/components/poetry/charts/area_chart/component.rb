# frozen_string_literal: true

module Poetry
  module Charts
    # The area chart family.
    module AreaChart
      # Renders an area chart - filled trends over an ordered axis,
      # optionally stacked - as server-computed SVG through the Cartesian
      # pipeline: the finished chart is in the initial HTML. Slots
      # compose the whole chart declaratively: grid, axes, series,
      # legend, tooltip.
      #
      # @example Two stacked series with a formatted month axis
      #   <%= poetry_area_chart(data:, config:, margin: { left: 12, right: 12 }) do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month, tick_formatter: ->(v) { v[0, 3] } %>
      #     <% c.with_area data_key: :desktop, stack: :a %>
      #     <% c.with_area data_key: :mobile, stack: :a %>
      #     <% c.with_legend %>
      #   <% end %>
      #
      # Series colors ride var(--color-<key>) (the Container emission);
      # per-x pixel coordinates are embedded for the tooltip controller.
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live
        include Poetry::Charts::ReferenceMarks

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Compose from slots: with_grid / with_x_axis(data_key:) / with_area(data_key:) / with_legend.",
          "Stack areas by giving them the same stack: id; offset: :expand makes the stack percent-based.",
          "Colors come from the config - never set fill/stroke on an area directly.",
          "gradient: true on an area gets the source's 5%/95% fade fill.",
          "Charts render complete on the server; the tooltip layer attaches separately.",
          "Entrance animation is on by default (source parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        # One with_area call's captured series config.
        Series = Data.define(:key, :stack, :curve, :fill_opacity, :gradient, :stroke_width)

        option :data, ActiveModel::Type::Value.new, required: true,
                                                    doc: "The rows to plot: an array of hashes, one per x category."
        option :config, ActiveModel::Type::Value.new, required: true,
                                                      doc: "The series config - key => { label:, color: } - naming " \
                                                           "and coloring every series."
        option :id, :string,
               doc: "Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id."
        option :width, :integer, default: 640,
                                 doc: "ViewBox width in pixels; the rendered chart scales to its container."
        option :height, :integer, default: 360, doc: "ViewBox height in pixels."
        option :margin, ActiveModel::Type::Value.new,
               doc: "Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults."
        option :offset, :symbol, default: :none,
                                 doc: "Stack baseline mode - :expand normalizes each stack to percentages."
        option :label, :string,
               doc: "Accessible name for the chart SVG; defaults to one built from the configured series."

        motion_options
        live_option

        validates :offset, inclusion: { in: Cartesian::OFFSETS }

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
        part "chart-motion-reveal", "The entrance clipPath rect (the ported area reveal) - the " \
                                    "motion stylesheet scales it 0 -> 1; only when animate"
        part "chart-grid", "The gridline group (with_grid) - horizontal and/or vertical rules " \
                           "across the plot"
        part "chart-cursor", "The hover cursor, hidden until the tooltip controller positions " \
                             "and reveals it at the active index - a vertical rule or a " \
                             "translucent band rect (bar charts)"
        part "chart-areas", "The area-mark group - a fill path plus top-curve stroke per series, " \
                            "clipped by the reveal rect while animating"
        part "chart-area", "One series' fill path (var(--color-<key>) or its gradient)",
             states: { "data-key" => "the series key" }
        part "chart-area-stroke", "One series' top-curve stroke path (the source strokes the " \
                                  "curve, never the area outline)",
             states: { "data-key" => "the series key" }
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
        part "chart-y-axis", "The y-axis tick-label group (with_y_axis)"
        part "chart-coordinates", "The embedded per-index geometry payload " \
                                  "(<script type=application/json>) the tooltip controller " \
                                  "reads - zero chart math in the browser"

        slot_doc :areas, "An area series bound to data_key:. Areas sharing a stack: id pile up; gradient: true fades " \
                         "the fill; curve: picks the interpolation."
        renders_many :areas, lambda { |data_key:, stack: nil, curve: :natural, fill_opacity: 0.4,
                                       gradient: false, stroke_width: 1|
          raise ArgumentError, "unknown curve #{curve.inspect}" unless CURVES.include?(curve.to_sym)

          (@series_entries ||= []) << Series.new(key: data_key.to_s, stack:, curve: curve.to_sym,
                                                 fill_opacity:, gradient:, stroke_width:)
          nil
        }

        include Poetry::Charts::CartesianFamily

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          areas? # force slot evaluation
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
            # The hidden implicit Y axis still drives the scale: default
            # tick count 5; an explicit with_y_axis supplies its own.
            y_tick_count: y_axis_config&.tick_count || 5,
            offset: offset
          )
        end

        # One series' fill path (the area between its baseline and top
        # curve).
        # @api private
        def series_path(entry)
          points = cartesian.points(entry)
          Geometry::Area.new(
            x: ->(p, _i) { p[:x] },
            y0: ->(p, _i) { p[:y0] },
            y1: ->(p, _i) { p[:y1] },
            curve: entry.curve,
            defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        # The stroke rides a SEPARATE path along the top curve only -
        # stroking the fill path's outline would also draw the left,
        # right, and baseline edges.
        # @api private
        def series_stroke_path(entry)
          points = cartesian.points(entry)
          Geometry::Line.new(
            x: ->(p, _i) { p[:x] },
            y: ->(p, _i) { p[:y1] },
            curve: entry.curve,
            defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
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

        # The per-series gradient def's id, scoped by the chart id.
        # @api private
        def gradient_id(entry)
          "#{chart_id}-fill-#{entry.key}"
        end

        # The series fill: its gradient url when gradient:, else its
        # config color var.
        # @api private
        def fill_for(entry)
          entry.gradient ? "url(##{gradient_id(entry)})" : "var(--color-#{entry.key})"
        end

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Area chart"

        # The embedded per-index geometry payload the tooltip controller
        # reads.
        # @api private
        def coordinates_json
          cartesian.coordinates.to_json
        end

        # -- live mode ---------------------------------------------------

        # The chart type in the live spec.
        # @api private
        def live_type = :area

        # The series list serialized into the live spec.
        # @api private
        def live_series
          series_entries.map { |e| { data_key: e.key, stack: e.stack, curve: e.curve }.compact }
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

        private :cartesian, :series_path, :series_stroke_path, :x_tick_label, :y_tick_label
        private :gradient_id, :fill_for, :svg_label_prefix, :coordinates_json, :live_type, :live_series, :live_axes
        private :live_x_scale_type, :live_category_axis?
      end
    end
  end
end
