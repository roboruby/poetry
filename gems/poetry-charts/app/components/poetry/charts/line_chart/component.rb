# frozen_string_literal: true

module Poetry
  module Charts
    module LineChart
      # The Line chart family (shadcn LineChart, 10 blocks): the cartesian
      # pipeline drawing stroked curves only - no fills. Adds the dots
      # variants (solid series-colored dots; per-point colors from a data
      # key) and point labels (the LabelList position=top look).
      #
      #   <%= poetry_chart :line, data:, config:, margin: { left: 12, right: 12 } do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month, tick_formatter: ->(v) { v[0, 3] } %>
      #     <% c.with_line data_key: :desktop %>
      #     <% c.with_line data_key: :mobile %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live

        AGENT_RULES = [
          "Compose from slots: with_grid / with_x_axis(data_key:) / with_line(data_key:) / with_legend.",
          "Lines default to stroke-width 2 and NO dots (the shadcn block look); dots: true adds them.",
          "dot_color_key: reads a per-row data key for per-point dot colors (the dots-colors block).",
          "labels: true stamps each value above its point; give the chart margin top when using it.",
          "Colors come from the config - never set stroke on a line directly.",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        CURVES = AreaChart::Component::CURVES

        Series = Data.define(:key, :curve, :stroke_width, :dots, :dot_radius, :dot_color_key, :labels) do
          # The cartesian pipeline contract (lines never stack).
          def stack = nil
        end

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 640
        option :height, :integer, default: 360
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

        motion_options
        live_option

        renders_many :lines, lambda { |data_key:, curve: :natural, stroke_width: 2, dots: false,
                                       dot_radius: 3, dot_color_key: nil, labels: false|
          raise ArgumentError, "unknown curve #{curve.inspect}" unless CURVES.include?(curve.to_sym)

          (@series_entries ||= []) << Series.new(key: data_key.to_s, curve: curve.to_sym, stroke_width:,
                                                 dots:, dot_radius:, dot_color_key: dot_color_key&.to_s, labels:)
          nil
        }

        renders_one :x_axis, lambda { |data_key:, tick_formatter: nil, tick_margin: 8|
          @x_axis_config = AreaChart::Component::AxisConfig.new(data_key: data_key.to_s, tick_formatter:,
                                                                tick_margin:, tick_count: nil)
          nil
        }

        renders_one :y_axis, lambda { |tick_count: 3, tick_formatter: nil, tick_margin: 8|
          @y_axis_config = AreaChart::Component::AxisConfig.new(data_key: nil, tick_formatter:,
                                                                tick_margin:, tick_count:)
          nil
        }

        renders_one :grid, lambda { |vertical: false, horizontal: true|
          @grid_config = AreaChart::Component::GridConfig.new(vertical:, horizontal:)
          nil
        }

        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        # Accepted for grammar stability; the tooltip layer is N10 W5.
        renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }

        def series_entries
          lines? # force slot evaluation (the N8 lazy-slot lesson)
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
            margin: margin || {},
            category_axis: x_axis?,
            y_tick_count: y_axis_config&.tick_count || 5
          )
        end

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
        def markers(entry)
          cartesian.points(entry).each_with_index.filter_map do |point, i|
            next if point[:value].nan?

            { x: point[:x], y: point[:y1], value: point[:value], row: data[i] }
          end
        end

        # Per-point dot color: the dot_color_key row value (CSS-validated),
        # else the series color.
        def dot_fill(entry, marker)
          if entry.dot_color_key
            color = marker[:row].to_h.transform_keys(&:to_s)[entry.dot_color_key].to_s
            raise ArgumentError, "dot color #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

            color
          else
            "var(--color-#{entry.key})"
          end
        end

        def x_tick_label(category)
          formatter = x_axis_config&.tick_formatter
          formatter ? formatter.call(category).to_s : category.to_s
        end

        def y_tick_label(tick)
          formatter = y_axis_config&.tick_formatter
          formatter ? formatter.call(tick).to_s : Geometry.js_number(tick.to_f)
        end

        def marker_label(marker)
          value = marker[:value]
          value == value.to_i ? value.to_i.to_s : value.to_s
        end

        def chart_id
          @chart_id ||= "chart-#{id.presence || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence || "Line chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        def coordinates_json
          cartesian.coordinates.to_json
        end

        # SVG attribute numbers: 2-decimal rounding, JS-style formatting.
        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end

        # -- live mode (Phase B) -----------------------------------------

        def live_type = :line

        def live_series
          series_entries.map { |e| { data_key: e.key, curve: e.curve } }
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
