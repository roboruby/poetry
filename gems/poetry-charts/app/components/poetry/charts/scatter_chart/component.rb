# frozen_string_literal: true

module Poetry
  module Charts
    module ScatterChart
      # The Scatter family (Phase C-W1, beyond the shadcn surface): BOTH
      # axes numeric - two recharts-niced linear scales - with per-point
      # marks. Each with_scatter series brings its own rows (or shares the
      # chart data); z sizing ports recharts' ZAxis semantics exactly (the
      # range is marker AREA in px2, default [64, 64]; r = sqrt(area/pi)).
      # The tooltip hits per POINT (data-index + pointerover, the pie
      # pattern) and the chrome shows the x/y(/z) rows with the point's
      # series name and color retinting per index - the polar wire shape,
      # zero controller changes.
      #
      #   <%= poetry_chart :scatter, data: points, config: config do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :height, name: "Height" %>
      #     <% c.with_y_axis data_key: :weight, name: "Weight" %>
      #     <% c.with_scatter key: :sample %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::ReferenceMarks
        include Poetry::Charts::ErrorBars

        AGENT_RULES = [
          "Both axes are numeric: with_x_axis(data_key:) / with_y_axis(data_key:) name the row keys to plot.",
          "with_scatter(key:) colors points var(--color-<key>); data: gives a series its own rows.",
          "with_z_axis(data_key:, range: [64, 144]) sizes points by a third dimension - " \
          "the range is marker AREA in px2 (recharts ZAxis).",
          "The tooltip hits per point and shows the x/y(/z) values with the series color.",
          "Entrance animation is on by default (recharts Scatter: 400ms linear); animate: false for a static chart."
        ].freeze

        Series = Data.define(:key, :data, :error_key, :error_width)
        AxisConfig = Data.define(:data_key, :tick_count, :tick_margin, :name)
        DEFAULT_Z_RANGE = [64, 64].freeze

        option :data, ActiveModel::Type::Value.new
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 640
        option :height, :integer, default: 360
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

        motion_options(duration: 400, easing: :linear)

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
        part "chart-scatters", "The scatter-mark group - every series' points flattened with " \
                               "a global index"
        part "chart-scatter-point", "One data point (<circle>) - r carries the z-axis area sizing",
             states: {
               "data-key" => "the series key",
               "data-index" => "the point's global index across every series",
               "data-active" => "runtime - the tooltip controller marks the hovered point"
             }
        part "chart-error-bars", "One series' error-whisker group (error_key:) - cap-stem-cap " \
                                 "paths in the foreground color",
             states: { "data-key" => "the series key" }
        part "chart-reference", "The reference-mark group (with_reference_line/_area/_dot), " \
                                "painted above the series"
        part "chart-x-axis", "The x-axis tick-label group (with_x_axis)"
        part "chart-y-axis", "The y-axis tick-label group (with_y_axis)"
        part "chart-coordinates", "The embedded per-index geometry payload " \
                                  "(<script type=application/json>) the tooltip controller " \
                                  "reads - zero chart math in the browser"

        renders_many :scatters, lambda { |key:, data: nil, error_key: nil, error_width: 5|
          (@series_entries ||= []) << Series.new(key: key.to_s, data: data,
                                                 error_key: error_key&.to_s, error_width:)
          nil
        }

        renders_one :x_axis, lambda { |data_key:, tick_count: 5, tick_margin: 8, name: nil|
          @x_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_count:, tick_margin:, name:)
          nil
        }

        renders_one :y_axis, lambda { |data_key:, tick_count: 5, tick_margin: 8, name: nil|
          @y_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_count:, tick_margin:, name:)
          nil
        }

        renders_one :z_axis, lambda { |data_key:, range: DEFAULT_Z_RANGE|
          @z_axis_config = { data_key: data_key.to_s, range: range }
          nil
        }

        renders_one :grid, lambda { |vertical: true, horizontal: true|
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
          scatters? # force slot evaluation (the N8 lazy-slot lesson)
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

        def z_axis_config
          z_axis?
          @z_axis_config
        end

        def grid_config
          grid?
          @grid_config
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # -- geometry: two recharts-niced linear scales -----------------------

        MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze

        def margins
          @margins ||= MARGIN.merge((margin || {}).to_h.symbolize_keys)
        end

        def plot_left = margins[:left].to_f + (y_axis? ? Cartesian::Y_AXIS_WIDTH : 0)
        def plot_right = width - margins[:right]
        def plot_top = margins[:top].to_f
        def plot_bottom = height - margins[:bottom] - (x_axis? ? Cartesian::X_AXIS_HEIGHT : 0)

        def rows(entry)
          @rows ||= {}
          @rows[entry.key] ||= (entry.data || data || []).map { |row| row.to_h.transform_keys(&:to_s) }
        end

        def axis_values(key)
          series_entries.flat_map { |entry| rows(entry).map { |row| row[key].to_f } }
        end

        # Both axes ride the recharts nice-ticks over [0, auto], the same
        # convention as every numeric axis in the engine.
        def x_ticks
          @x_ticks ||= nice_ticks(axis_values(x_axis_config.data_key), x_axis_config.tick_count)
        end

        def y_ticks
          @y_ticks ||= nice_ticks(axis_values(y_axis_config.data_key), y_axis_config.tick_count)
        end

        def nice_ticks(values, count)
          max = values.max || 1
          Geometry::NiceTicks.nice_ticks([[0, values.min || 0].min, max], count)
        end

        def x_scale
          @x_scale ||= Geometry::Scale::Linear.new(domain: [x_ticks.first, x_ticks.last],
                                                   range: [plot_left, plot_right])
        end

        def y_scale
          @y_scale ||= Geometry::Scale::Linear.new(domain: [y_ticks.first, y_ticks.last],
                                                   range: [plot_bottom, plot_top])
        end

        # recharts ZAxis: a linear scale from the z data domain onto the
        # AREA range; the circle radius is sqrt(area / pi).
        def z_scale
          @z_scale ||= begin
            values = axis_values(z_axis_config[:data_key])
            Geometry::Scale::Linear.new(domain: [values.min || 0, values.max || 1],
                                        range: z_axis_config[:range].map(&:to_f))
          end
        end

        def point_radius(row)
          area = if z_axis_config
                   value = row[z_axis_config[:data_key]].to_f
                   z_scale.domain.first == z_scale.domain.last ? z_axis_config[:range].first.to_f : z_scale.call(value)
                 else
                   DEFAULT_Z_RANGE.first.to_f
                 end
          Math.sqrt(area / Math::PI)
        end

        Point = Data.define(:index, :key, :cx, :cy, :r, :row)

        # All series flattened with a GLOBAL index - the tooltip's per-point
        # hit space.
        def points
          @points ||= begin
            index = -1
            series_entries.flat_map do |entry|
              rows(entry).map do |row|
                index += 1
                Point.new(index: index, key: entry.key,
                          cx: x_scale.call(row[x_axis_config.data_key].to_f),
                          cy: y_scale.call(row[y_axis_config.data_key].to_f),
                          r: point_radius(row), row: row)
              end
            end
          end
        end

        # -- the tooltip payload (the per-index anchors wire) ------------------

        def axis_label(axis_config, fallback)
          (axis_config.respond_to?(:name) && axis_config.name.presence) || fallback
        end

        def coordinates_json
          value_rows = { "x" => x_axis_config, "y" => y_axis_config }
          # No "names": the x/y rows keep their axis labels; the point's
          # series shows as the tooltip LABEL (categories) and the
          # indicator retints through colors.
          payload = {
            "layout" => "polar",
            "categories" => points.map { |p| chart_config.label_for(p.key, p.key) },
            "colors" => points.map { |p| chart_config[p.key]&.color || "var(--color-#{p.key})" },
            "anchors" => points.map { |p| [p.cx.round(2), p.cy.round(2)] },
            "values" => value_rows.to_h do |dimension, axis|
              [dimension, points.map { |p| Poetry::Charts.display_value(p.row[axis.data_key]) }]
            end
          }
          if z_axis_config
            payload["values"]["z"] = points.map { |p| Poetry::Charts.display_value(p.row[z_axis_config[:data_key]]) }
          end
          payload.to_json
        end

        # The chrome rows are the axis DIMENSIONS (x/y/z), labeled from the
        # axis name: (or its data key); the indicator retints per point.
        def tooltip_layer_component
          entries = {
            x: { label: axis_label(x_axis_config, x_axis_config.data_key) },
            y: { label: axis_label(y_axis_config, y_axis_config.data_key) }
          }
          entries[:z] = { label: z_axis_config[:data_key] } if z_axis_config
          TooltipLayer::Component.new(
            config: Poetry::Charts::Config.wrap(entries),
            series_keys: entries.keys.map(&:to_s),
            indicator: tooltip_config.fetch(:indicator, :dot),
            hide_label: tooltip_config.fetch(:hide_label, false),
            hide_indicator: tooltip_config.fetch(:hide_indicator, false)
          )
        end

        # Points are hit by pointerover on the marked circle, not bisect -
        # the svg gains the enter action after the module's set.
        use_stimulus do
          on :svg do
            controller(TooltipWiring::CONTROLLER, if: :tooltip?) { action :enter, on: :pointerover }
          end
        end

        def chart_id
          @chart_id ||= "chart-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence ||
            "Scatter chart: #{series_entries.map { |e| chart_config[e.key]&.label || e.key }.join(", ")}"
        end

        # Reference marks speak numbers on BOTH axes here (the concern's
        # defaults are categorical).
        def ref_x_pixel(value) = x_scale.call(value.to_f)
        def ref_y_pixel(value) = y_scale.call(value.to_f)

        def ref_plot
          { left: plot_left, right: plot_right, top: plot_top, bottom: plot_bottom }
        end

        def tick_label(tick)
          Geometry.js_number(tick.to_f)
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end
      end
    end
  end
end
