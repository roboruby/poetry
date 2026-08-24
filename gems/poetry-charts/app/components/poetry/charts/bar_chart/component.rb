# frozen_string_literal: true

module Poetry
  module Charts
    module BarChart
      # The Bar chart family (shadcn BarChart), vertical columns by default
      # (orientation: :horizontal flips them): band-scale positioning with recharts'
      # exact bar math - barCategoryGap 10% trims each side of the band,
      # barGap 4 separates side-by-side groups, stacked bars share a slot.
      # Rounded corners are per-corner (radius: 8 or [tl, tr, br, bl] - the
      # stacked blocks round only their outer edge), negatives drop below
      # the zero baseline, and per-cell fills come from a data key or a
      # guarded proc (the negative block's sign coloring).
      #
      #   <%= poetry_chart :bar, data:, config: do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :month, tick_formatter: ->(v) { v[0, 3] } %>
      #     <% c.with_bar data_key: :desktop, radius: 8 %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live
        include Poetry::Charts::BarMath
        include Poetry::Charts::ReferenceMarks
        include Poetry::Charts::ErrorBars

        AGENT_RULES = [
          "Compose from slots: with_grid / with_x_axis(data_key:) / with_bar(data_key:) / with_legend.",
          "radius: 8 rounds all corners; stacked bars use arrays - [0,0,4,4] bottom bar, [4,4,0,0] top bar.",
          "Stack bars with the same stack: id; negatives automatically drop below the zero line.",
          "cell_fill: ->(row, value) { ... } colors bars per datum (validated CSS-safe); color_key: reads a row key.",
          "active_index: highlights one bar (fill-opacity 0.8 + dashed stroke - the active block look).",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        Series = Data.define(:key, :stack, :radius, :labels, :label_key, :color_key,
                             :cell_fill, :active_index, :stroke_width, :error_key, :error_width) do
          def stack_or_self = stack || key
        end

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 640
        option :height, :integer, default: 360
        option :margin, ActiveModel::Type::Value.new
        option :offset, :symbol, default: :none
        option :label, :string

        motion_options(duration: 400)
        live_option
        option :bar_gap, :integer, default: 4
        option :bar_category_gap, :string, default: "10%"
        # :vertical = columns (the default); :horizontal = bars growing
        # rightward (recharts' confusingly-named layout="vertical") - the
        # category axis moves to the Y side (with_y_axis data_key:) and the
        # numeric axis hides, exactly the horizontal/mixed block shape.
        option :orientation, :symbol, default: :vertical

        validates :offset, inclusion: { in: Cartesian::OFFSETS }
        validates :orientation, inclusion: { in: Cartesian::LAYOUTS }

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
        part "chart-bars", "The bar-mark group wrapping every series"
        part "chart-bar-series", "One series' bar group",
             states: { "data-key" => "the series key" }
        part "chart-bar", "One bar cell (a per-corner rounded-rect path)",
             states: {
               "data-key" => "the series key",
               "data-index" => "the datum index",
               "data-active" => "the highlighted cell - server-rendered from active_index:, " \
                                "and the tooltip controller marks the hovered index at runtime",
               "data-motion-origin" => { condition: "when animate - the zero edge the entrance " \
                                                    "grows from",
                                         values: %w[bottom top left right] }
             }
        part "chart-labels", "One series' value-label group (labels: true)",
             states: { "data-key" => "the series key" }
        part "chart-x-axis", "The x-axis tick-label group (with_x_axis)"
        part "chart-y-axis", "The y-axis tick-label group (with_y_axis)"
        part "chart-coordinates", "The embedded per-index geometry payload " \
                                  "(<script type=application/json>) the tooltip controller " \
                                  "reads - zero chart math in the browser"

        renders_many :bars, lambda { |data_key:, stack: nil, radius: 0, labels: false, label_key: nil,
                                      color_key: nil, cell_fill: nil, active_index: nil, stroke_width: 2,
                                      error_key: nil, error_width: 5|
          (@series_entries ||= []) << Series.new(key: data_key.to_s, stack:, radius:, labels:,
                                                 label_key: label_key&.to_s, color_key: color_key&.to_s,
                                                 cell_fill:, active_index:, stroke_width:,
                                                 error_key: error_key&.to_s, error_width:)
          nil
        }

        # In the horizontal orientation the Y axis IS the category axis -
        # give it the data_key (the horizontal/mixed block shape). The
        # CartesianFamily value-axis hook, so the include below declares
        # this shape between x_axis and grid.
        def self.value_axis_slot
          renders_one :y_axis, lambda { |data_key: nil, tick_count: 3, tick_formatter: nil, tick_margin: 8|
            @y_axis_config = AxisConfig.new(data_key: data_key&.to_s, tick_formatter:,
                                            tick_margin:, tick_count:)
            nil
          }
        end

        include Poetry::Charts::CartesianFamily

        def series_entries
          bars? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        def horizontal?
          orientation == :horizontal
        end

        def cartesian
          @cartesian ||= Cartesian.new(
            data: data,
            series: series_entries,
            width: width,
            height: height,
            x_key: horizontal? ? y_axis_config&.data_key : x_axis_config&.data_key,
            margin: live_margin,
            category_axis: horizontal? ? y_axis? : x_axis?,
            value_axis: !horizontal? && y_axis?,
            # Horizontal charts hide the numeric axis (implicit tickCount 5);
            # vertical ones take the visible Y axis's count when present.
            y_tick_count: horizontal? ? 5 : (y_axis_config&.tick_count || 5),
            offset: offset,
            x_scale_type: :band,
            layout: orientation
          )
        end

        # recharts combineAllBarPositions (no explicit barSize): stacked
        # bars share a slot; groups sit side by side inside the band.
        def bar_slots
          @bar_slots ||= bar_slots_for(series_entries)
        end

        def cells(entry)
          bar_cells(entry, bar_slots.fetch(entry.stack_or_self))
        end

        def bar_path(entry, cell)
          bar_path_for(entry.radius, cell)
        end

        # Fill resolution: cell_fill proc, else color_key row value, else
        # the series color - everything reaching the attribute is guarded.
        def cell_fill(entry, cell)
          color = if entry.cell_fill
                    entry.cell_fill.call(cell[:row], cell[:value]).to_s
                  elsif entry.color_key
                    cell[:row].to_h.transform_keys(&:to_s)[entry.color_key].to_s
                  else
                    return "var(--color-#{entry.key})"
                  end
          raise ArgumentError, "bar fill #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

          color
        end

        def active?(entry, cell)
          entry.active_index == cell[:index]
        end

        def cell_label(entry, cell)
          if entry.label_key
            cell[:row].to_h.transform_keys(&:to_s)[entry.label_key].to_s
          else
            value = cell[:value]
            value == value.to_i ? value.to_i.to_s : value.to_s
          end
        end

        def x_tick_label(category)
          formatter = x_axis_config&.tick_formatter
          formatter ? formatter.call(category).to_s : category.to_s
        end

        # The horizontal layout's category labels (the Y side).
        def category_tick_label(category)
          formatter = y_axis_config&.tick_formatter
          formatter ? formatter.call(category).to_s : category.to_s
        end

        def y_tick_label(tick)
          formatter = y_axis_config&.tick_formatter
          formatter ? formatter.call(tick).to_s : Geometry.js_number(tick.to_f)
        end

        # ChartFamily#svg_label's chart-type lead-in.
        def svg_label_prefix = "Bar chart"

        def coordinates_json
          cartesian.coordinates.to_json
        end

        # -- live mode ---------------------------------------------------

        def live_type = :bar

        def live_series
          series_entries.map { |e| { data_key: e.key, stack: e.stack }.compact }
        end

        def live_axes
          axes = {}
          if horizontal?
            axes[:y] = { data_key: y_axis_config.data_key } if y_axis_config&.data_key
          else
            axes[:x] = { data_key: x_axis_config.data_key } if x_axis_config&.data_key
            axes[:y] = { tick_count: y_axis_config.tick_count } if y_axis_config
          end
          axes
        end

        def live_x_scale_type = :band
        def live_category_axis? = horizontal? ? y_axis? : x_axis?

        def live_frame_extras
          {
            "barGap" => bar_gap,
            "barCategoryGap" => bar_category_gap,
            "series" => series_entries.to_h { |e| [e.key, { "radius" => e.radius }] }
          }
        end
      end
    end
  end
end
