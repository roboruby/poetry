# frozen_string_literal: true

module Poetry
  module Charts
    module ComposedChart
      # The Composed family (Phase C-W2, beyond the shadcn surface):
      # area, bar, and line marks on ONE shared cartesian - recharts
      # ComposedChart. All mark slots push into a single accumulator, so
      # slot declaration order IS paint order (recharts' children order).
      # The x scale is always a band (bars need one; lines and areas ride
      # the band centers), the y domain is shared across every mark, and
      # stack ids are namespaced per mark type so an area stack can never
      # co-stack with a bar stack by accident.
      #
      #   <%= poetry_chart :composed, data: data, config: config do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month %>
      #     <% c.with_bar data_key: :visitors, radius: 4 %>
      #     <% c.with_line data_key: :trend, stroke_width: 2 %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::BarMath
        include Poetry::Charts::ReferenceMarks

        AGENT_RULES = [
          "Mix marks freely: with_area / with_bar / with_line - declaration order is paint order.",
          "All marks share the x band and ONE y domain; lines and areas ride the band centers.",
          "stack: ids only combine within the same mark type (a bar stack never joins an area stack).",
          "Colors come from the config - never set fill/stroke on a mark directly.",
          "Entrance animation is on by default; each mark uses its own recharts mechanism."
        ].freeze

        Series = Data.define(:mark, :key, :stack, :curve, :fill_opacity, :gradient,
                             :stroke_width, :dots, :dot_radius, :radius) do
          def stack_or_self = stack || key
        end

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 640
        option :height, :integer, default: 360
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

        motion_options
        option :bar_gap, :integer, default: 4
        option :bar_category_gap, :string, default: "10%"

        renders_many :areas, lambda { |data_key:, stack: nil, curve: :natural, fill_opacity: 0.4,
                                       gradient: false, stroke_width: 1|
          push_series(:area, key: data_key, stack: stack && "area-#{stack}",
                             curve: curve.to_sym, fill_opacity:, gradient:, stroke_width:)
        }

        renders_many :bars, lambda { |data_key:, stack: nil, radius: 0|
          push_series(:bar, key: data_key, stack: stack && "bar-#{stack}", radius: radius)
        }

        renders_many :lines, lambda { |data_key:, curve: :natural, stroke_width: 2,
                                       dots: false, dot_radius: 4|
          push_series(:line, key: data_key, curve: curve.to_sym, stroke_width:,
                             dots:, dot_radius:)
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

        renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }

        def series_entries
          # Force every mark slot (the N8 lazy-slot lesson); the shared
          # accumulator preserves declaration order across slot types.
          areas?
          bars?
          lines?
          @series_entries ||= []
        end

        def bar_entries = series_entries.select { |e| e.mark == :bar }

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

        def horizontal? = false

        def cartesian
          @cartesian ||= Cartesian.new(
            data: data,
            series: series_entries,
            width: width,
            height: height,
            x_key: x_axis_config&.data_key,
            margin: margin || {},
            category_axis: x_axis?,
            y_tick_count: y_axis_config&.tick_count || 5,
            x_scale_type: :band
          )
        end

        # -- per-mark geometry -------------------------------------------------

        def area_path(entry)
          points = cartesian.points(entry)
          Geometry::Area.new(
            x: ->(p, _i) { p[:x] }, y0: ->(p, _i) { p[:y0] }, y1: ->(p, _i) { p[:y1] },
            curve: entry.curve, defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        def top_line_path(entry)
          points = cartesian.points(entry)
          Geometry::Line.new(
            x: ->(p, _i) { p[:x] }, y: ->(p, _i) { p[:y1] },
            curve: entry.curve, defined: ->(p, _i) { !p[:value].nan? }
          ).path(points)
        end

        def bar_slots
          @bar_slots ||= bar_slots_for(bar_entries)
        end

        def cells(entry)
          bar_cells(entry, bar_slots.fetch(entry.stack_or_self))
        end

        def bar_path(entry, cell)
          bar_path_for(entry.radius, cell)
        end

        def line_markers(entry)
          cartesian.points(entry).each_with_index.filter_map do |point, i|
            next if point[:value].nan?

            { index: i, x: point[:x], y: point[:y1] }
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

        def gradient_id(entry)
          "#{chart_id}-fill-#{entry.key}"
        end

        def area_fill(entry)
          entry.gradient ? "url(##{gradient_id(entry)})" : "var(--color-#{entry.key})"
        end

        def chart_id
          @chart_id ||= "chart-#{id.presence || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence || "Composed chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        def coordinates_json
          cartesian.coordinates.to_json
        end

        # Line and area marks show hover dots; bars reflect via data-index.
        def active_dot_markers(entry)
          return [] if entry.mark == :bar

          super
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end

        SERIES_DEFAULTS = { stack: nil, curve: nil, fill_opacity: nil, gradient: nil,
                            stroke_width: nil, dots: nil, dot_radius: nil, radius: nil }.freeze
        private_constant :SERIES_DEFAULTS

        private

        def push_series(mark, key:, **attrs)
          attrs = SERIES_DEFAULTS.merge(attrs)
          if attrs[:curve] && !AreaChart::Component::CURVES.include?(attrs[:curve])
            raise ArgumentError, "unknown curve #{attrs[:curve].inspect}"
          end

          (@series_entries ||= []) << Series.new(mark: mark, key: key.to_s, **attrs)
          nil
        end
      end
    end
  end
end
