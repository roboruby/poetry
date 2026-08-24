# frozen_string_literal: true

module Poetry
  module Charts
    # The scatter chart family.
    module ScatterChart
      # Renders a scatter chart: BOTH axes numeric - two auto-niced
      # linear scales - with per-point marks. Each with_scatter series
      # brings its own rows (or shares the chart data); the z axis sizes
      # markers by AREA in px2 (default range [64, 64]; r =
      # sqrt(area/pi)). The tooltip hits per POINT (data-index +
      # pointerover) and the chrome shows the x/y(/z) rows with the
      # point's series name and color retinting per index.
      #
      # @example Points over two named numeric axes
      #   <%= poetry_chart :scatter, data: points, config: config do |c| %>
      #     <% c.with_grid %>
      #     <% c.with_x_axis data_key: :height, name: "Height" %>
      #     <% c.with_y_axis data_key: :weight, name: "Weight" %>
      #     <% c.with_scatter key: :sample %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion
        include Poetry::Charts::ReferenceMarks
        include Poetry::Charts::ErrorBars

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Both axes are numeric: with_x_axis(data_key:) / with_y_axis(data_key:) name the row keys to plot.",
          "with_scatter(key:) colors points var(--color-<key>); data: gives a series its own rows.",
          "with_z_axis(data_key:, range: [64, 144]) sizes points by a third dimension - " \
          "the range is marker AREA in px2 (the source's z-axis contract).",
          "The tooltip hits per point and shows the x/y(/z) values with the series color.",
          "Entrance animation is on by default (400ms linear, source-exact); animate: false for a static chart."
        ].freeze

        # One with_scatter call's captured series config.
        Series = Data.define(:key, :data, :error_key, :error_width)
        # One numeric axis slot's captured config.
        AxisConfig = Data.define(:data_key, :tick_count, :tick_margin, :name)
        # The marker AREA range (px2) when no z axis sizes the points.
        DEFAULT_Z_RANGE = [64, 64].freeze

        option :data, ActiveModel::Type::Value.new,
               doc: "Default rows for series that don't bring their own data: - one hash per point."
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

        slot_doc :scatters, "A point series colored by key:. data: gives it its own rows; error_key: adds error " \
                            "whiskers."
        renders_many :scatters, lambda { |key:, data: nil, error_key: nil, error_width: 5|
          (@series_entries ||= []) << Series.new(key: key.to_s, data: data,
                                                 error_key: error_key&.to_s, error_width:)
          nil
        }

        slot_doc :x_axis, "The numeric x axis: data_key: names the row key to plot; name: labels its tooltip row."
        renders_one :x_axis, lambda { |data_key:, tick_count: 5, tick_margin: 8, name: nil|
          @x_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_count:, tick_margin:, name:)
          nil
        }

        slot_doc :y_axis, "The numeric y axis: data_key: names the row key to plot; name: labels its tooltip row."
        renders_one :y_axis, lambda { |data_key:, tick_count: 5, tick_margin: 8, name: nil|
          @y_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_count:, tick_margin:, name:)
          nil
        }

        slot_doc :z_axis, "A third dimension sizing the markers: range: is marker AREA in px2 mapped linearly from " \
                          "the data_key: values."
        renders_one :z_axis, lambda { |data_key:, range: DEFAULT_Z_RANGE|
          @z_axis_config = { data_key: data_key.to_s, range: range }
          nil
        }

        slot_doc :grid, "The gridlines: both directions by default."
        renders_one :grid, lambda { |vertical: true, horizontal: true|
          @grid_config = GridConfig.new(vertical:, horizontal:)
          nil
        }

        slot_doc :legend, "The legend row: align:, items:, and hide_icon:."
        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        slot_doc :tooltip, "The hover tooltip - per-point x/y(/z) rows under the series name."
        renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }

        # Points are hit by pointerover on the marked circle, not bisect -
        # the svg gains the enter action after the module's set.
        use_stimulus do
          on :svg do
            controller(TooltipWiring::CONTROLLER, if: :tooltip?) { action :enter, on: :pointerover }
          end
        end

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          scatters? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        # The x-axis slot's captured config, forcing lazy slot evaluation.
        # @api private
        def x_axis_config
          x_axis?
          @x_axis_config
        end

        # The y-axis slot's captured config, forcing lazy slot evaluation.
        # @api private
        def y_axis_config
          y_axis?
          @y_axis_config
        end

        # The z-axis slot's captured config, forcing lazy slot evaluation.
        # @api private
        def z_axis_config
          z_axis?
          @z_axis_config
        end

        # The grid slot's captured config, forcing lazy slot evaluation.
        # @api private
        def grid_config
          grid?
          @grid_config
        end

        # -- geometry: two auto-niced linear scales ---------------------------

        # The default margin - a slim, even inset on all sides.
        MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze

        # The margin option merged over the defaults.
        # @api private
        def margins
          @margins ||= MARGIN.merge((margin || {}).to_h.symbolize_keys)
        end

        # The plot rect's left edge, inset for the y axis when present.
        # @api private
        def plot_left = margins[:left].to_f + (y_axis? ? Cartesian::Y_AXIS_WIDTH : 0)
        # The plot rect's right edge.
        # @api private
        def plot_right = width - margins[:right]
        # The plot rect's top edge.
        # @api private
        def plot_top = margins[:top].to_f
        # The plot rect's bottom edge, inset for the x axis when present.
        # @api private
        def plot_bottom = height - margins[:bottom] - (x_axis? ? Cartesian::X_AXIS_HEIGHT : 0)

        # Memoized per SLOT (object identity), never per key: two series may
        # share a key with different data:, and a key-keyed memo would
        # silently render the first series' rows twice.
        # @api private
        def rows(entry)
          @rows ||= {}.compare_by_identity
          @rows[entry] ||= (entry.data || data || []).map { |row| row.to_h.transform_keys(&:to_s) }
        end

        # Every series' values for one row key, flattened.
        # @api private
        def axis_values(key)
          series_entries.flat_map { |entry| rows(entry).map { |row| row[key].to_f } }
        end

        # Both axes ride the shared nice-ticks over [0, auto], the same
        # convention as every numeric axis in the engine.
        # @api private
        def x_ticks
          @x_ticks ||= nice_ticks(axis_values(x_axis_config.data_key), x_axis_config.tick_count)
        end

        # The y axis's niced tick values.
        # @api private
        def y_ticks
          @y_ticks ||= nice_ticks(axis_values(y_axis_config.data_key), y_axis_config.tick_count)
        end

        # Niced ticks over the values' [min-or-0, max] domain.
        # @api private
        def nice_ticks(values, count)
          max = values.max || 1
          Geometry::NiceTicks.nice_ticks([[0, values.min || 0].min, max], count)
        end

        # The x scale from the tick domain onto the plot width.
        # @api private
        def x_scale
          @x_scale ||= Geometry::Scale::Linear.new(domain: [x_ticks.first, x_ticks.last],
                                                   range: [plot_left, plot_right])
        end

        # The y scale from the tick domain onto the plot height.
        # @api private
        def y_scale
          @y_scale ||= Geometry::Scale::Linear.new(domain: [y_ticks.first, y_ticks.last],
                                                   range: [plot_bottom, plot_top])
        end

        # The z axis: a linear scale from the z data domain onto the AREA
        # range; the circle radius is sqrt(area / pi).
        # @api private
        def z_scale
          @z_scale ||= begin
            values = axis_values(z_axis_config[:data_key])
            Geometry::Scale::Linear.new(domain: [values.min || 0, values.max || 1],
                                        range: z_axis_config[:range].map(&:to_f))
          end
        end

        # A point's radius from its z value (or the default area).
        # @api private
        def point_radius(row)
          area = if z_axis_config
                   value = row[z_axis_config[:data_key]].to_f
                   z_scale.domain.first == z_scale.domain.last ? z_axis_config[:range].first.to_f : z_scale.call(value)
                 else
                   DEFAULT_Z_RANGE.first.to_f
                 end
          Math.sqrt(area / Math::PI)
        end

        # One computed point: its position, radius, series key, and row.
        Point = Data.define(:index, :key, :cx, :cy, :r, :row)

        # All series flattened with a GLOBAL index - the tooltip's per-point
        # hit space.
        # @api private
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

        # An axis's tooltip-row label: its name:, else the fallback.
        # @api private
        def axis_label(axis_config, fallback)
          (axis_config.respond_to?(:name) && axis_config.name.presence) || fallback
        end

        # The embedded per-point geometry payload the tooltip controller
        # reads.
        # @api private
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
        # @api private
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

        # The whole-name override of ChartFamily#svg_label: scatter's
        # series read from the config by key, not from its entries.
        # @api private
        def svg_label
          label.presence ||
            "Scatter chart: #{series_entries.map { |e| chart_config[e.key]&.label || e.key }.join(", ")}"
        end

        # Reference marks speak numbers on BOTH axes here (the concern's
        # defaults are categorical).
        # @api private
        def ref_x_pixel(value) = x_scale.call(value.to_f)
        # Reference y values map through the y scale.
        # @api private
        def ref_y_pixel(value) = y_scale.call(value.to_f)

        # The plot rect's edges, keyed for the mark painters.
        # @api private
        def ref_plot
          { left: plot_left, right: plot_right, top: plot_top, bottom: plot_bottom }
        end

        # A tick's label, integers shown bare.
        # @api private
        def tick_label(tick)
          Geometry.js_number(tick.to_f)
        end

        private :x_axis_config, :y_axis_config, :z_axis_config, :grid_config, :margins, :plot_left
        private :plot_right, :plot_top, :plot_bottom, :rows, :axis_values, :x_ticks, :y_ticks, :nice_ticks, :x_scale
        private :y_scale, :z_scale, :point_radius, :points, :axis_label, :coordinates_json, :tooltip_layer_component
        private :svg_label, :ref_x_pixel, :ref_y_pixel, :ref_plot, :tick_label
      end
    end
  end
end
