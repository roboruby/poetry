# frozen_string_literal: true

module Poetry
  module Charts
    # The composed chart family.
    module ComposedChart
      # Renders a composed chart: area, bar, and line marks on ONE
      # shared cartesian. All mark slots push into a single accumulator,
      # so slot declaration order IS paint order. The x scale is always a
      # band (bars need one; lines and areas ride the band centers), the
      # y domain is shared across every mark, and stack ids are
      # namespaced per mark type so an area stack can never co-stack
      # with a bar stack by accident.
      #
      # @example Bars with a trend line on one plot
      #   <%= poetry_chart :composed, data: data, config: config do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month %>
      #     <% c.with_bar data_key: :visitors, radius: 4 %>
      #     <% c.with_line data_key: :trend, stroke_width: 2 %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::BarMath
        include Poetry::Charts::ReferenceMarks

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Mix marks freely: with_area / with_bar / with_line - declaration order is paint order.",
          "All marks share the x band and ONE y domain; lines and areas ride the band centers.",
          "stack: ids only combine within the same mark type (a bar stack never joins an area stack).",
          "Colors come from the config - never set fill/stroke on a mark directly.",
          "Entrance animation is on by default; each mark keeps its own reveal mechanism."
        ].freeze

        # One mark slot's captured series config, tagged by mark type.
        Series = Data.define(:mark, :key, :stack, :curve, :fill_opacity, :gradient,
                             :stroke_width, :dots, :dot_radius, :radius) do
          # The band-slot group id: the stack, else the series' own key.
          def stack_or_self = stack || key
        end

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
        option :label, :string,
               doc: "Accessible name for the chart SVG; defaults to one built from the configured series."

        motion_options
        option :bar_gap, :integer, default: 4, doc: "Pixels between side-by-side bars inside one category band."
        option :bar_category_gap, :string, default: "10%",
                                           doc: "Band trim on each side: a percent string of the band width, or a " \
                                                "bare pixel number."

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
        part "chart-bar-series", "One series' bar group",
             states: { "data-key" => "the series key" }
        part "chart-bar", "One bar cell (a per-corner rounded-rect path)",
             states: {
               "data-key" => "the series key",
               "data-index" => "the datum index",
               "data-active" => "runtime - the tooltip controller marks the hovered index",
               "data-motion-origin" => { condition: "when animate - the zero edge the entrance " \
                                                    "grows from",
                                         values: %w[bottom top] }
             }
        part "chart-lines", "The line-mark group - each series' curve plus its companion marks"
        part "chart-line", "One series' stroked curve - pathLength=1 when animating so the " \
                           "dash draw-in needs no measurement",
             states: { "data-key" => "the series key" }
        part "chart-dots", "One series' point-dot group (dots: true)",
             states: { "data-key" => "the series key" }
        part "chart-dot", "One point dot (<circle>)"
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

        slot_doc :areas, "An area mark bound to data_key:; areas sharing a stack: id pile up (area stacks never join " \
                         "bar stacks)."
        renders_many :areas, lambda { |data_key:, stack: nil, curve: :natural, fill_opacity: 0.4,
                                       gradient: false, stroke_width: 1|
          push_series(:area, key: data_key, stack: stack && "area-#{stack}",
                             curve: curve.to_sym, fill_opacity:, gradient:, stroke_width:)
        }

        slot_doc :bars, "A bar mark bound to data_key:; radius: rounds corners; bars sharing a stack: id pile up " \
                        "within the bar marks."
        renders_many :bars, lambda { |data_key:, stack: nil, radius: 0|
          push_series(:bar, key: data_key, stack: stack && "bar-#{stack}", radius: radius)
        }

        slot_doc :lines, "A line mark bound to data_key:; dots: marks each point."
        renders_many :lines, lambda { |data_key:, curve: :natural, stroke_width: 2,
                                       dots: false, dot_radius: 4|
          push_series(:line, key: data_key, curve: curve.to_sym, stroke_width:,
                             dots:, dot_radius:)
        }

        include Poetry::Charts::CartesianFamily

        # The captured Series configs in declaration order across every
        # mark type.
        # @api private
        def series_entries
          # Force every mark slot (slots evaluate lazily); the shared
          # accumulator preserves declaration order across slot types.
          areas?
          bars?
          lines?
          @series_entries ||= []
        end

        # Just the bar-mark series, for the band slot math.
        # @api private
        def bar_entries = series_entries.select { |e| e.mark == :bar }

        # The BarMath host contract: composed charts are vertical only.
        # @api private
        def horizontal? = false

        # The chart's cartesian geometry, built once per render.
        # @api private
        def cartesian
          @cartesian ||= Cartesian.new(
            data: data,
            series: series_entries,
            width: width,
            height: height,
            x_key: x_axis_config&.data_key,
            margin: margin || {},
            category_axis: x_axis?,
            value_axis: y_axis?,
            y_tick_count: y_axis_config&.tick_count || 5,
            x_scale_type: :band
          )
        end

        # -- per-mark geometry -------------------------------------------------

        # One area mark's fill path.
        # @api private
        def area_path(entry)
          points = cartesian.points(entry)
          Geometry::Area.new(
            x: ->(p, _i) { p[:x] }, y0: ->(p, _i) { p[:y0] }, y1: ->(p, _i) { p[:y1] },
            curve: entry.curve, defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        # A mark's top-curve stroke path (line marks, and area strokes).
        # @api private
        def top_line_path(entry)
          points = cartesian.points(entry)
          Geometry::Line.new(
            x: ->(p, _i) { p[:x] }, y: ->(p, _i) { p[:y1] },
            curve: entry.curve, defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        # The per-group band slots for the bar marks.
        # @api private
        def bar_slots
          @bar_slots ||= bar_slots_for(bar_entries)
        end

        # One bar series' rects, positioned in its band slot.
        # @api private
        def cells(entry)
          bar_cells(entry, bar_slots.fetch(entry.stack_or_self))
        end

        # One bar cell's rounded-rect path.
        # @api private
        def bar_path(entry, cell)
          bar_path_for(entry.radius, cell)
        end

        # The visible points for a line mark's dots (NaN renders nothing).
        # @api private
        def line_markers(entry)
          cartesian.points(entry).each_with_index.filter_map do |point, i|
            next if point[:value].nan?

            { index: i, x: point[:x], y: point[:y1] }
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

        # The per-series gradient def's id, scoped by the chart id.
        # @api private
        def gradient_id(entry)
          "#{chart_id}-fill-#{entry.key}"
        end

        # An area mark's fill: its gradient url when gradient:, else its
        # config color var.
        # @api private
        def area_fill(entry)
          entry.gradient ? "url(##{gradient_id(entry)})" : "var(--color-#{entry.key})"
        end

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Composed chart"

        # The embedded per-index geometry payload the tooltip controller
        # reads.
        # @api private
        def coordinates_json
          cartesian.coordinates.to_json
        end

        # Line and area marks show hover dots; bars reflect via data-index.
        # @api private
        def active_dot_markers(entry)
          return [] if entry.mark == :bar

          super
        end

        SERIES_DEFAULTS = { stack: nil, curve: nil, fill_opacity: nil, gradient: nil,
                            stroke_width: nil, dots: nil, dot_radius: nil, radius: nil }.freeze
        private_constant :SERIES_DEFAULTS

        private

        def push_series(mark, key:, **attrs)
          attrs = SERIES_DEFAULTS.merge(attrs)
          if attrs[:curve] && !CURVES.include?(attrs[:curve])
            raise ArgumentError, "unknown curve #{attrs[:curve].inspect}"
          end

          (@series_entries ||= []) << Series.new(mark: mark, key: key.to_s, **attrs)
          nil
        end

        private :bar_entries, :cartesian, :area_path, :top_line_path, :bar_slots, :cells
        private :bar_path, :line_markers, :x_tick_label, :y_tick_label, :gradient_id, :area_fill, :svg_label_prefix
        private :coordinates_json, :active_dot_markers
      end
    end
  end
end
