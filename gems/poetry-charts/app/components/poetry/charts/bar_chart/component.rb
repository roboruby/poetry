# frozen_string_literal: true

module Poetry
  module Charts
    module BarChart
      # The Bar chart family (shadcn BarChart), vertical columns (the
      # horizontal layout is W4b): band-scale positioning with recharts'
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
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::Live

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
                             :cell_fill, :active_index, :stroke_width) do
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

        renders_many :bars, lambda { |data_key:, stack: nil, radius: 0, labels: false, label_key: nil,
                                      color_key: nil, cell_fill: nil, active_index: nil, stroke_width: 2|
          (@series_entries ||= []) << Series.new(key: data_key.to_s, stack:, radius:, labels:,
                                                 label_key: label_key&.to_s, color_key: color_key&.to_s,
                                                 cell_fill:, active_index:, stroke_width:)
          nil
        }

        renders_one :x_axis, lambda { |data_key:, tick_formatter: nil, tick_margin: 8|
          @x_axis_config = AreaChart::Component::AxisConfig.new(data_key: data_key.to_s, tick_formatter:,
                                                                tick_margin:, tick_count: nil)
          nil
        }

        # In the horizontal orientation the Y axis IS the category axis -
        # give it the data_key (the horizontal/mixed block shape).
        renders_one :y_axis, lambda { |data_key: nil, tick_count: 3, tick_formatter: nil, tick_margin: 8|
          @y_axis_config = AreaChart::Component::AxisConfig.new(data_key: data_key&.to_s, tick_formatter:,
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
          bars? # force slot evaluation (the N8 lazy-slot lesson)
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
            margin: margin || {},
            category_axis: horizontal? ? y_axis? : x_axis?,
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
          @bar_slots ||= begin
            groups = series_entries.map(&:stack_or_self).uniq
            band = cartesian.band_width
            gap = bar_gap.to_f
            trim = percent_value(bar_category_gap, band)
            gap = 0.0 if band - (2 * trim) - ((groups.length - 1) * gap) <= 0

            size = (band - (2 * trim) - ((groups.length - 1) * gap)) / groups.length
            size = Geometry.js_round(size).to_f if size > 1

            groups.each_with_index.to_h do |group, i|
              [group, { offset: trim + ((size + gap) * i), size: size }]
            end
          end
        end

        # One rect per category for a series: band position + slot offset
        # along the category side, the value span on the other, normalized
        # so width/height stay positive (negatives keep the zero edge).
        def cells(entry)
          slot = bar_slots.fetch(entry.stack_or_self)
          points = cartesian.points(entry)

          points.each_with_index.filter_map do |point, i|
            next if point[:value].nan?

            base = { index: i, value: point[:value], row: data[i] }
            if horizontal?
              left = [point[:x0], point[:x1]].min
              right = [point[:x0], point[:x1]].max
              base.merge(x: left, y: cartesian.x_positions[i] + slot[:offset],
                         width: right - left, height: slot[:size])
            else
              top = [point[:y0], point[:y1]].min
              bottom = [point[:y0], point[:y1]].max
              base.merge(x: cartesian.x_positions[i] + slot[:offset], y: top,
                         width: slot[:size], height: bottom - top)
            end
          end
        end

        # The zero edge the entrance animation grows from: sign x
        # orientation (stacked segments grow from their own zero-side edge,
        # matching recharts' per-rect baseline interpolation).
        def motion_origin(cell)
          if horizontal?
            cell[:value].negative? ? "right" : "left"
          else
            cell[:value].negative? ? "top" : "bottom"
          end
        end

        # radius: Integer (all corners) or [tl, tr, br, bl] (the stacked
        # blocks). Clamped to half the rect like recharts' Rectangle.
        def bar_path(entry, cell)
          radii = entry.radius.is_a?(Array) ? entry.radius.map(&:to_f) : Array.new(4, entry.radius.to_f)
          max = [cell[:width] / 2.0, cell[:height] / 2.0].min
          tl, tr, br, bl = radii.map { |r| r.clamp(0.0, max) }
          x = cell[:x]
          y = cell[:y]
          w = cell[:width]
          h = cell[:height]
          f = ->(v) { fnum(v) }

          "M#{f.call(x)},#{f.call(y + tl)}" \
            "#{"A#{f.call(tl)},#{f.call(tl)},0,0,1,#{f.call(x + tl)},#{f.call(y)}" if tl.positive?}" \
            "L#{f.call(x + w - tr)},#{f.call(y)}" \
            "#{"A#{f.call(tr)},#{f.call(tr)},0,0,1,#{f.call(x + w)},#{f.call(y + tr)}" if tr.positive?}" \
            "L#{f.call(x + w)},#{f.call(y + h - br)}" \
            "#{"A#{f.call(br)},#{f.call(br)},0,0,1,#{f.call(x + w - br)},#{f.call(y + h)}" if br.positive?}" \
            "L#{f.call(x + bl)},#{f.call(y + h)}" \
            "#{"A#{f.call(bl)},#{f.call(bl)},0,0,1,#{f.call(x)},#{f.call(y + h - bl)}" if bl.positive?}Z"
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

        def chart_id
          @chart_id ||= "chart-#{id.presence || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence || "Bar chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        def coordinates_json
          cartesian.coordinates.to_json
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end

        # -- live mode (Phase B) -----------------------------------------

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

        private

        # recharts getPercentValue: "10%" of the band, or a plain px number.
        def percent_value(value, total)
          text = value.to_s
          text.end_with?("%") ? total * (text.to_f / 100.0) : text.to_f
        end
      end
    end
  end
end
