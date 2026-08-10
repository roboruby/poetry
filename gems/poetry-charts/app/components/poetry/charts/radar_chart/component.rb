# frozen_string_literal: true

module Poetry
  module Charts
    module RadarChart
      # The Radar family (shadcn RadarChart, 14 blocks - the biggest, and
      # the one shadcn-vue still cannot draw): categories spaced clockwise
      # from 12 o'clock (recharts: startAngle 90, endAngle -270), values on
      # a nice [0, auto] radius scale, series as closed polygons with the
      # 0.6 fill, polygon/circle grids at the radius ticks, and angle-axis
      # labels around the rim. The tooltip hits per CATEGORY through
      # server-rendered transparent wedges (fill=transparent stays
      # hit-testable) - the multi-series chrome with the category label,
      # zero client math.
      #
      #   <%= poetry_chart :radar, data:, config: do |c| %>
      #     <% c.with_angle_axis data_key: :month %>
      #     <% c.with_grid %>
      #     <% c.with_radar data_key: :desktop %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        AGENT_RULES = [
          "Compose from slots: with_angle_axis(data_key:) / with_grid / with_radar(data_key:) / with_legend.",
          "Radars fill at 0.6 opacity by default; lines-only = fill_opacity: 0, stroke_width: 2.",
          "with_grid type: :circle swaps polygons for circles; fill: :desktop tints every grid ring " \
          "(opacity 0.2, compounding toward the center - the grid-fill look).",
          "dots: true marks every vertex (r 4, solid).",
          "Colors come from the config - never set fill/stroke on a radar directly.",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        Series = Data.define(:data_key, :fill_opacity, :stroke_width, :dots, :dot_radius) do
          # The TooltipWiring contract.
          def key = data_key
        end
        GridConfig = Data.define(:type, :radial_lines, :fill, :opacity)

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 250
        option :height, :integer, default: 250
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

        motion_options
        option :outer_radius, ActiveModel::Type::Value.new, default: "80%"

        part "chart-svg", "The chart canvas (<svg>) - the aria-label surface, the tooltip's " \
                          "focus/keyboard surface (role=application when it attaches), and " \
                          "the motion rig's mount",
             states: {
               "data-animate" => "when animate (the default) - the entrance tier's flag the " \
                                 "motion stylesheet and controller key off",
               "data-motion" => { condition: "runtime, when animate - the motion engine's lifecycle stamp",
                                  values: %w[entrance morph settled] }
             },
             vars: {
               "--poetry-motion-delay" => "the motion rig's entrance delay (animation_begin)",
               "--poetry-motion-duration" => "the motion rig's entrance duration (animation_duration)",
               "--poetry-motion-easing" => "the motion rig's easing keyword (animation_easing)",
               "--poetry-motion-center" => "the polar center the CSS entrance scales the series from"
             }
        part "chart-polar-grid", "The polar grid (<g>, aria-hidden) - ring and spoke linework " \
                                 "behind the series"
        part "chart-radars", "The series layer (<g>) - every radar polygon renders here; the " \
                             "CSS entrance scales this group from the polar center"
        part "chart-radar", "One series' closed polygon (<path>) - config color, 0.6 fill by default",
             states: { "data-key" => "always - the series key" }
        part "chart-dots", "A series' vertex dots (<g>), rendered when dots: true",
             states: { "data-key" => "always - the series key" }
        part "chart-dot", "One vertex dot (<circle>) - solid, at the series color"
        part "chart-angle-axis", "The category labels around the rim (<g> of <text>)"
        part "chart-hit-wedges", "The tooltip's hit layer (<g>), rendered when the tooltip attaches"
        part "chart-hit-wedge", "One per-category hit wedge (<path>, transparent but painted so " \
                                "it hit-tests) - the tooltip's hover target",
             states: {
               "data-index" => "always - the datum index",
               "data-active" => "the hovered/arrow-keyed category - the tooltip controller " \
                                "reflects the active index here at runtime"
             }
        part "chart-coordinates", "The embedded JSON payload (<script>) the tooltip controller " \
                                  "reads - per-category anchors and pre-formatted values, zero " \
                                  "chart math in the browser"

        renders_many :radars, lambda { |data_key:, fill_opacity: 0.6, stroke_width: 0, dots: false, dot_radius: 4|
          (@series_entries ||= []) << Series.new(data_key: data_key.to_s, fill_opacity:, stroke_width:,
                                                 dots:, dot_radius:)
          nil
        }

        renders_one :angle_axis, lambda { |data_key:, tick_formatter: nil|
          @angle_axis_config = { data_key: data_key.to_s, tick_formatter: tick_formatter }
          nil
        }

        renders_one :grid, lambda { |type: :polygon, radial_lines: true, fill: nil, opacity: 0.2|
          @grid_config = GridConfig.new(type: type.to_sym, radial_lines:, fill: fill&.to_s, opacity:)
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
          radars? # force slot evaluation (the N8 lazy-slot lesson)
          @series_entries ||= []
        end

        def angle_axis_config
          angle_axis?
          @angle_axis_config
        end

        def grid_config
          grid?
          @grid_config
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # -- geometry ---------------------------------------------------------

        MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze

        def plot
          @plot ||= begin
            m = MARGIN.merge((margin || {}).to_h.symbolize_keys)
            { left: m[:left].to_f, top: m[:top].to_f,
              width: width - m[:left] - m[:right], height: height - m[:top] - m[:bottom] }
          end
        end

        def cx = plot[:left] + (plot[:width] / 2.0)
        def cy = plot[:top] + (plot[:height] / 2.0)

        def rows
          @rows ||= data.map { |row| row.to_h.transform_keys(&:to_s) }
        end

        def categories
          key = angle_axis_config&.fetch(:data_key)
          key ? rows.map { |row| row[key] } : (0...rows.length).to_a
        end

        # Clockwise from 12 o'clock: recharts RadarChart startAngle 90.
        def angle_at(index)
          90 - (index * (360.0 / rows.length))
        end

        def radius_px
          @radius_px ||= Polar.percent_value(outer_radius, Polar.max_radius(plot[:width], plot[:height]),
                                             Polar.max_radius(plot[:width], plot[:height]) * 0.8)
        end

        # recharts' PolarRadiusAxis auto-nices the [0, dataMax] domain
        # (tickCount 5), so the outer ring is the ROUNDED max and the top
        # datum sits just inside it (dataMax 305 -> [0, 320], Feb at 95.3%).
        def radius_ticks
          @radius_ticks ||= begin
            max = series_entries.flat_map { |e| rows.map { |row| row[e.data_key].to_f } }.max || 1
            Geometry::NiceTicks.nice_ticks([0, max], 5)
          end
        end

        def radius_for(value)
          (value.to_f / radius_ticks.last) * radius_px
        end

        def vertex(entry, index)
          Polar.polar_to_cartesian(cx, cy, radius_for(rows[index][entry.data_key]), angle_at(index))
        end

        def polygon_path(points)
          "M#{points.map { |x, y| "#{fnum(x)},#{fnum(y)}" }.join("L")}Z"
        end

        def series_path(entry)
          polygon_path(rows.each_index.map { |i| vertex(entry, i) })
        end

        # Grid polygons/circles at each nonzero radius tick.
        def grid_radii
          radius_ticks.reject(&:zero?).map { |tick| radius_for(tick) }
        end

        def grid_polygon(radius)
          polygon_path(rows.each_index.map { |i| Polar.polar_to_cartesian(cx, cy, radius, angle_at(i)) })
        end

        # The radial spoke's outer endpoint (template helper - bare Polar
        # does not resolve from compiled ERB scope).
        def spoke_end(index)
          Polar.polar_to_cartesian(cx, cy, radius_px, angle_at(index))
        end

        # Lands in an inline style= (the class's fill-none beats a fill
        # attribute), so the token is validated - never interpolate a raw
        # string into CSS.
        def grid_fill_attribute
          return nil unless grid_config&.fill

          token = grid_config.fill
          raise ArgumentError, "grid fill #{token.inspect} is not a series key" unless token.match?(/\A[\w-]+\z/)

          "var(--color-#{token})"
        end

        # Angle-axis labels around the rim, anchored by which side of the
        # circle they sit on.
        def angle_label(index)
          angle = angle_at(index)
          x, y = Polar.polar_to_cartesian(cx, cy, radius_px + 10, angle)
          cos = Math.cos(-Polar::RADIAN * angle)
          anchor = if cos > 0.2 then "start"
                   elsif cos < -0.2 then "end"
                   else "middle"
                   end
          category = categories[index]
          formatter = angle_axis_config[:tick_formatter]
          { x: x, y: y, anchor: anchor, text: formatter ? formatter.call(category).to_s : category.to_s }
        end

        # The invisible per-category hit wedges the tooltip rides
        # (fill=transparent is painted, so it hit-tests; fill=none would not).
        def hit_wedge(index)
          half = 180.0 / rows.length
          Polar.sector_path(cx: cx, cy: cy, inner_radius: 0, outer_radius: radius_px,
                            start_angle: angle_at(index) - half, end_angle: angle_at(index) + half)
        end

        # -- the tooltip payload: polar anchors, cartesian-style rows ----------

        def coordinates_json
          {
            "layout" => "polar",
            "categories" => categories.map(&:to_s),
            "anchors" => rows.each_index.map do |i|
              Polar.polar_to_cartesian(cx, cy, radius_px * 0.7, angle_at(i)).map { |v| v.round(2) }
            end,
            "values" => series_entries.to_h do |entry|
              [entry.data_key, rows.map { |row| Poetry::Charts.display_value(row[entry.data_key]) }]
            end
          }.to_json
        end

        def chart_id
          @chart_id ||= "chart-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence || "Radar chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        # Vertex dots are hit by pointerover, not bisect - the svg gains
        # the enter action after the module's set.
        use_stimulus do
          on :svg do
            controller(TooltipWiring::CONTROLLER, if: :tooltip?) { action :enter, on: :pointerover }
          end
        end

        # The polar center, so the motion stylesheet can scale the entrance
        # from it (recharts lerps every vertex from (cx, cy) - a uniform
        # scale is the identical per-frame geometry).
        def motion_style_extras
          "--poetry-motion-center: #{fnum(cx)}px #{fnum(cy)}px"
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end
      end
    end
  end
end
