# frozen_string_literal: true

module Poetry
  module Charts
    # The radar chart family.
    module RadarChart
      # Renders a radar chart: categories spaced clockwise from
      # 12 o'clock, values on a nice [0, auto] radius scale, series as
      # closed polygons with a 0.6 fill, polygon or circle grids at the
      # radius ticks, and angle-axis labels around the rim. The tooltip
      # hits per CATEGORY through server-rendered transparent wedges
      # (fill=transparent stays hit-testable) - the multi-series chrome
      # with the category label, zero client math.
      #
      # @example One filled series over month categories
      #   <%= poetry_chart :radar, data:, config: do |c| %>
      #     <% c.with_angle_axis data_key: :month %>
      #     <% c.with_grid %>
      #     <% c.with_radar data_key: :desktop %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Compose from slots: with_angle_axis(data_key:) / with_grid / with_radar(data_key:) / with_legend.",
          "Radars fill at 0.6 opacity by default; lines-only = fill_opacity: 0, stroke_width: 2.",
          "with_grid type: :circle swaps polygons for circles; fill: :desktop tints every grid ring " \
          "(opacity 0.2, compounding toward the center - the grid-fill look).",
          "dots: true marks every vertex (r 4, solid).",
          "Colors come from the config - never set fill/stroke on a radar directly.",
          "Entrance animation is on by default (source parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        # One with_radar call's captured series config.
        Series = Data.define(:data_key, :fill_opacity, :stroke_width, :dots, :dot_radius) do
          # The TooltipWiring contract.
          def key = data_key
        end
        # The with_grid slot's captured config.
        GridConfig = Data.define(:type, :radial_lines, :fill, :opacity)

        option :data, ActiveModel::Type::Value.new, required: true,
                                                    doc: "The rows to plot: an array of hashes, one per category."
        option :config, ActiveModel::Type::Value.new, required: true,
                                                      doc: "The series config - key => { label:, color: } - naming " \
                                                           "and coloring every series."
        option :id, :string,
               doc: "Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id."
        option :width, :integer, default: 250,
                                 doc: "ViewBox width in pixels; the rendered chart scales to its container."
        option :height, :integer, default: 250, doc: "ViewBox height in pixels."
        option :margin, ActiveModel::Type::Value.new,
               doc: "Margin overrides ({ top:, right:, bottom:, left: }), merged over the slim polar default."
        option :label, :string,
               doc: "Accessible name for the chart SVG; defaults to one built from the configured series."

        motion_options
        option :outer_radius, ActiveModel::Type::Value.new, default: "80%",
                                                            doc: "The rim radius: a percent string of the max " \
                                                                 "radius, or pixels."

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

        slot_doc :radars, "A radar series bound to data_key:. fill_opacity: 0 with stroke_width: 2 draws lines only; " \
                          "dots: marks every vertex."
        renders_many :radars, lambda { |data_key:, fill_opacity: 0.6, stroke_width: 0, dots: false, dot_radius: 4|
          (@series_entries ||= []) << Series.new(data_key: data_key.to_s, fill_opacity:, stroke_width:,
                                                 dots:, dot_radius:)
          nil
        }

        slot_doc :angle_axis, "The category labels around the rim: data_key: names the field; tick_formatter: " \
                              "reshapes each label."
        renders_one :angle_axis, lambda { |data_key:, tick_formatter: nil|
          @angle_axis_config = { data_key: data_key.to_s, tick_formatter: tick_formatter }
          nil
        }

        slot_doc :grid, "The polar grid: type: :circle swaps polygons for circles; radial_lines: false drops the " \
                        "spokes; fill: tints every ring with a series color at opacity:."
        renders_one :grid, lambda { |type: :polygon, radial_lines: true, fill: nil, opacity: 0.2|
          @grid_config = GridConfig.new(type: type.to_sym, radial_lines:, fill: fill&.to_s, opacity:)
          nil
        }

        slot_doc :legend, "The legend row: align:, items:, and hide_icon:."
        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        slot_doc :tooltip, "The hover tooltip - multi-series rows under the category label."
        renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }

        # The polar chassis (margin/plot/center + the pointerover hit).
        # PolarFamily alone: radar keeps TooltipWiring's multi-series
        # chrome and its own payload below.
        include Poetry::Charts::PolarFamily

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          radars? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        # The angle-axis slot's captured config, forcing lazy slot
        # evaluation.
        # @api private
        def angle_axis_config
          angle_axis?
          @angle_axis_config
        end

        # The grid slot's captured config, forcing lazy slot evaluation.
        # @api private
        def grid_config
          grid?
          @grid_config
        end

        # -- geometry ---------------------------------------------------------

        # The data rows with stringified keys.
        # @api private
        def rows
          @rows ||= data.map { |row| row.to_h.transform_keys(&:to_s) }
        end

        # The category labels: the angle axis's data key values, else
        # bare indexes.
        # @api private
        def categories
          key = angle_axis_config&.fetch(:data_key)
          key ? rows.map { |row| row[key] } : (0...rows.length).to_a
        end

        # Clockwise from 12 o'clock: category 0 sits at the top
        # (90 degrees), later categories sweep clockwise.
        # @api private
        def angle_at(index)
          90 - (index * (360.0 / rows.length))
        end

        # The rim radius resolved to pixels.
        # @api private
        def radius_px
          @radius_px ||= Polar.percent_value(outer_radius, Polar.max_radius(plot[:width], plot[:height]),
                                             Polar.max_radius(plot[:width], plot[:height]) * 0.8)
        end

        # The radius domain auto-nices [0, data max] into 5 ticks, so the
        # outer ring is the ROUNDED max and the top datum sits just
        # inside it (data max 305 -> [0, 320], the peak at 95.3%).
        # @api private
        def radius_ticks
          @radius_ticks ||= begin
            max = series_entries.flat_map { |e| rows.map { |row| row[e.data_key].to_f } }.max || 1
            Geometry::NiceTicks.nice_ticks([0, max], 5)
          end
        end

        # A value's distance from the center, scaled to the tick domain.
        # @api private
        def radius_for(value)
          (value.to_f / radius_ticks.last) * radius_px
        end

        # One series point: the category's angle at the value's radius.
        # @api private
        def vertex(entry, index)
          Polar.polar_to_cartesian(cx, cy, radius_for(rows[index][entry.data_key]), angle_at(index))
        end

        # A closed polygon path through the given points.
        # @api private
        def polygon_path(points)
          "M#{points.map { |x, y| "#{fnum(x)},#{fnum(y)}" }.join("L")}Z"
        end

        # One series' closed polygon through all its vertices.
        # @api private
        def series_path(entry)
          polygon_path(rows.each_index.map { |i| vertex(entry, i) })
        end

        # Grid polygons/circles at each nonzero radius tick.
        # @api private
        def grid_radii
          radius_ticks.reject(&:zero?).map { |tick| radius_for(tick) }
        end

        # One grid ring's polygon at the given radius.
        # @api private
        def grid_polygon(radius)
          polygon_path(rows.each_index.map { |i| Polar.polar_to_cartesian(cx, cy, radius, angle_at(i)) })
        end

        # The radial spoke's outer endpoint (template helper - bare Polar
        # does not resolve from compiled ERB scope).
        # @api private
        def spoke_end(index)
          Polar.polar_to_cartesian(cx, cy, radius_px, angle_at(index))
        end

        # Lands in an inline style= (the class's fill-none beats a fill
        # attribute), so the token is validated - never interpolate a raw
        # string into CSS.
        # @api private
        def grid_fill_attribute
          return nil unless grid_config&.fill

          token = grid_config.fill
          raise ArgumentError, "grid fill #{token.inspect} is not a series key" unless token.match?(/\A[\w-]+\z/)

          "var(--color-#{token})"
        end

        # Angle-axis labels around the rim, anchored by which side of the
        # circle they sit on.
        # @api private
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
        # @api private
        def hit_wedge(index)
          half = 180.0 / rows.length
          Polar.sector_path(cx: cx, cy: cy, inner_radius: 0, outer_radius: radius_px,
                            start_angle: angle_at(index) - half, end_angle: angle_at(index) + half)
        end

        # -- the tooltip payload: polar anchors, cartesian-style rows ----------

        # The embedded per-category geometry payload the tooltip
        # controller reads.
        # @api private
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

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Radar chart"

        # The polar center, so the motion stylesheet can scale the
        # entrance from it - a uniform scale from (cx, cy) matches
        # per-vertex interpolation frame for frame.
        # @api private
        def motion_style_extras
          "--poetry-motion-center: #{fnum(cx)}px #{fnum(cy)}px"
        end

        private :angle_axis_config, :grid_config, :rows, :categories, :angle_at, :radius_px
        private :radius_ticks, :radius_for, :vertex, :polygon_path, :series_path, :grid_radii, :grid_polygon, :spoke_end
        private :grid_fill_attribute, :angle_label, :hit_wedge, :coordinates_json, :svg_label_prefix
        private :motion_style_extras
      end
    end
  end
end
