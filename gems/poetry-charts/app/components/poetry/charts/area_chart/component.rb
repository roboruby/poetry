# frozen_string_literal: true

module Poetry
  module Charts
    module AreaChart
      # The Area chart family (shadcn AreaChart, 10 blocks): server-rendered
      # SVG through the Cartesian pipeline - the finished chart is in the
      # initial HTML. Slots mirror the recharts grammar one-to-one so any
      # shadcn block translates mechanically:
      #
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
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live
        include Poetry::Charts::ReferenceMarks

        AGENT_RULES = [
          "Compose from slots: with_grid / with_x_axis(data_key:) / with_area(data_key:) / with_legend.",
          "Stack areas by giving them the same stack: id; offset: :expand makes the stack percent-based.",
          "Colors come from the config - never set fill/stroke on an area directly.",
          "gradient: true on an area gets the shadcn 5%/95% fade fill.",
          "Charts render complete on the server; the tooltip layer attaches separately.",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        CURVES = %i[natural linear step step_before step_after monotone_x].freeze

        Series = Data.define(:key, :stack, :curve, :fill_opacity, :gradient, :stroke_width)
        AxisConfig = Data.define(:data_key, :tick_formatter, :tick_margin, :tick_count)
        GridConfig = Data.define(:vertical, :horizontal)

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 640
        option :height, :integer, default: 360
        option :margin, ActiveModel::Type::Value.new
        option :offset, :symbol, default: :none
        option :label, :string

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
        part "chart-motion-reveal", "The entrance clipPath rect (recharts' area reveal) - the " \
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
        part "chart-area-stroke", "One series' top-curve stroke path (recharts strokes the " \
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

        # Lambda slots accumulate config into ivars and return nil (the
        # breadcrumb pattern - slot wrappers do not delegate to lambda
        # return values); readers force evaluation via the slot predicate
        # (slots evaluate lazily).
        renders_many :areas, lambda { |data_key:, stack: nil, curve: :natural, fill_opacity: 0.4,
                                       gradient: false, stroke_width: 1|
          raise ArgumentError, "unknown curve #{curve.inspect}" unless CURVES.include?(curve.to_sym)

          (@series_entries ||= []) << Series.new(key: data_key.to_s, stack:, curve: curve.to_sym,
                                                 fill_opacity:, gradient:, stroke_width:)
          nil
        }

        renders_one :x_axis, lambda { |data_key:, tick_formatter: nil, tick_margin: 8|
          @x_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_formatter:, tick_margin:, tick_count: nil)
          nil
        }

        renders_one :y_axis, lambda { |tick_count: 3, tick_formatter: nil, tick_margin: 8|
          @y_axis_config = AxisConfig.new(data_key: nil, tick_formatter:, tick_margin:, tick_count:)
          nil
        }

        renders_one :grid, lambda { |vertical: false, horizontal: true|
          @grid_config = GridConfig.new(vertical:, horizontal:)
          nil
        }

        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        # The slot captures options only; the tooltip layer itself
        # (controller + chrome wiring) is declared by TooltipWiring.
        renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }

        def series_entries
          areas? # force slot evaluation
          @series_entries ||= []
        end

        def x_axis_config
          x_axis?
          @x_axis_config
        end

        def y_axis_config
          y_axis?
          @y_axis_config
        end

        def grid_config
          grid?
          @grid_config
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

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
            # The Y axis strip: the axes block shows ticks with tickCount 3;
            # the implicit hidden axis uses 5 (recharts implicitYAxis).
            y_tick_count: y_axis_config&.tick_count || 5,
            offset: offset
          )
        end

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
        # recharts renders Area as fill path + curve path; stroking the
        # area outline (left/right/baseline edges) is not the shadcn look.
        def series_stroke_path(entry)
          points = cartesian.points(entry)
          Geometry::Line.new(
            x: ->(p, _i) { p[:x] },
            y: ->(p, _i) { p[:y1] },
            curve: entry.curve,
            defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        def x_tick_label(category)
          formatter = x_axis_config&.tick_formatter
          formatter ? formatter.call(category).to_s : category.to_s
        end

        def y_tick_label(tick)
          formatter = y_axis_config&.tick_formatter
          formatter ? formatter.call(tick).to_s : Geometry.js_number(tick.to_f)
        end

        def gradient_id(entry)
          "#{chart_id}-fill-#{entry.key}"
        end

        def fill_for(entry)
          entry.gradient ? "url(##{gradient_id(entry)})" : "var(--color-#{entry.key})"
        end

        def chart_id
          @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
        end

        # The accessible name for the role=img SVG: explicit label: or a
        # sensible default from the configured series.
        def svg_label
          label.presence || "Area chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        def coordinates_json
          cartesian.coordinates.to_json
        end

        # SVG attribute numbers: 2-decimal rounding, JS-style formatting
        # (bare integers) - keeps the markup compact and stable.
        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end

        # -- live mode ---------------------------------------------------

        def live_type = :area

        def live_series
          series_entries.map { |e| { data_key: e.key, stack: e.stack, curve: e.curve }.compact }
        end

        def live_axes
          axes = {}
          axes[:x] = { data_key: x_axis_config.data_key } if x_axis_config&.data_key
          axes[:y] = { tick_count: y_axis_config.tick_count } if y_axis_config
          axes
        end

        def live_x_scale_type = :point
        def live_category_axis? = x_axis?
      end
    end
  end
end
