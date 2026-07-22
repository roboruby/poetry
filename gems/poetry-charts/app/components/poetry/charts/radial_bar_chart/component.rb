# frozen_string_literal: true

module Poetry
  module Charts
    module RadialBarChart
      # The RadialBar family (shadcn RadialBarChart, 6 blocks): one angular
      # bar per data row on concentric rings between inner_radius and
      # outer_radius, sweep proportional to value over the angle span.
      # Rings divide the radial band with the SAME math as vertical bars
      # (10% trim, 4px gaps); stacked radial bars share the ring and stack
      # along the ANGLE; corner_radius rounds arc ends with recharts'
      # tangent-circle construction; `background: true` draws the muted
      # track ring; polar-grid discs (the shape/text blocks' gauge look)
      # and the donut-style center label round out the family.
      #
      #   <%= poetry_chart :radial, data: browsers, config: config,
      #                    inner_radius: 30, outer_radius: 110 do |c| %>
      #     <% c.with_radial_bar data_key: :visitors, background: true %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        AGENT_RULES = [
          "One ring per data row; rows carry their color in a fill key (var(--color-<name>)).",
          "background: true draws the muted track ring behind each bar (the gauge look).",
          "Stack two radial bars with the same stack: id - they share the ring and stack by ANGLE.",
          "corner_radius rounds the arc ends (10 on a 10px ring = full pill caps).",
          "with_polar_grid(radii:, fills:) draws the shape/text blocks' disc track; " \
          "with_center_label fills the middle.",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        Series = Data.define(:data_key, :stack, :background, :corner_radius, :color_key,
                             :labels, :label_key)

        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 250
        option :height, :integer, default: 250
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

        motion_options
        option :name_key, :string, default: "name"
        option :start_angle, :integer, default: 0
        option :end_angle, :integer, default: 360
        option :inner_radius, ActiveModel::Type::Value.new, default: "20%"
        option :outer_radius, ActiveModel::Type::Value.new, default: "80%"
        # The angle-axis maximum: nil = recharts' [0, dataMax] domain - the
        # largest ring closes the full sweep EXACTLY (nicing it would leave
        # a notch); stacked gauges pass the stack total when the segments
        # should fill the span (the stacked block's full half-ring).
        option :max_value, ActiveModel::Type::Value.new

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
               "--poetry-motion-easing" => "the motion rig's easing keyword (animation_easing)"
             }
        part "chart-polar-grid", "The polar grid (<g>, aria-hidden) - ring and spoke linework " \
                                 "behind the series"
        part "chart-radial-series", "One series' ring group (<g>)",
             states: { "data-key" => "always - the series key" }
        part "chart-radial-background", "The muted track ring (<path>) behind a bar, rendered " \
                                        "when background: true"
        part "chart-radial-bar", "One angular bar (<path>) - a ring per data row, sweep " \
                                 "proportional to value",
             states: {
               "data-key" => "always - the series key",
               "data-index" => "on the first series' bars - the datum index the tooltip walks",
               "data-active" => "the hovered/arrow-keyed bar - the tooltip controller reflects " \
                                "the active index here at runtime",
               "data-motion-group" => "when animate - the motion rig's sweep group (one per ring)",
               "data-motion-sector" => "when animate - the motion rig's server-computed sector params " \
                                       "for the fan-out sweep"
             }
        part "chart-labels", "A series' value labels (<g> of <text>, aria-hidden), rendered when " \
                             "the series opts into labels",
             states: { "data-key" => "always - the series key" }
        part "chart-center-label", "The center text (<text>) - title tspan plus optional subtitle " \
                                   "filling the chart's middle"
        part "chart-coordinates", "The embedded JSON payload (<script>) the tooltip controller " \
                                  "reads - per-category anchors and pre-formatted values, zero " \
                                  "chart math in the browser"

        renders_many :radial_bars, lambda { |data_key:, stack: nil, background: false, corner_radius: 0,
                                            color_key: :fill, labels: nil, label_key: nil|
          (@series_entries ||= []) << Series.new(data_key: data_key.to_s, stack:, background:,
                                                 corner_radius:, color_key: color_key&.to_s,
                                                 labels: labels&.to_sym, label_key: label_key&.to_s)
          nil
        }

        # radial_lines defaults ON (recharts PolarGrid) - the faint value
        # spokes that show through ring gaps and the open wedge; the gauge
        # blocks (shape/text) turn them off explicitly, as upstream does.
        renders_one :polar_grid, lambda { |radii: nil, fills: nil, radial_lines: true|
          @polar_grid_config = { radii: radii, fills: Array(fills), radial_lines: radial_lines }
          nil
        }

        # compact: the stacked half-gauge's smaller number sitting just
        # above the flat baseline (text-2xl at cy-16 / caption at cy+4);
        # the default is the full gauge's big centered number (text-4xl).
        renders_one :center_label, lambda { |title:, subtitle: nil, compact: false|
          @center_label_config = { title: title, subtitle: subtitle, compact: compact }
          nil
        }

        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        renders_one :tooltip, lambda { |**options|
          @tooltip_config = { hide_label: true }.merge(options)
          nil
        }

        def series_entries
          radial_bars? # force slot evaluation (the N8 lazy-slot lesson)
          @series_entries ||= []
        end

        def polar_grid_config
          polar_grid?
          @polar_grid_config
        end

        def center_label_config
          center_label?
          @center_label_config
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # -- geometry ---------------------------------------------------------

        MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze
        TRIM = 0.1
        GAP = 4.0

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

        def radii
          @radii ||= begin
            max = Polar.max_radius(plot[:width], plot[:height])
            [Polar.percent_value(inner_radius, max, max * 0.2),
             Polar.percent_value(outer_radius, max, max * 0.8)]
          end
        end

        # The radial band: one ring per ROW, the vertical-bar math rotated
        # onto the radius axis (10% trim each side, 4px between rings).
        def ring(index)
          inner, outer = radii
          band = (outer - inner) / rows.length
          trim = band * TRIM
          thickness = band - (2 * trim)
          ring_inner = inner + (band * index) + trim
          [ring_inner, ring_inner + thickness]
        end

        def stacked?
          series_entries.any?(&:stack)
        end

        # recharts' PolarAngleAxis default domain is [0, dataMax] over the
        # RAW cell values, NOT the stacked totals - so a stacked ring maps
        # each segment through the max single value and the overflow past
        # end_angle is clipped (the stacked half-gauge: mobile 570 of
        # dataMax 1260 = 81deg, desktop stacks on and clips at 180deg).
        # An explicit max_value: overrides (a caller who wants the stack
        # total to fill the span exactly passes it).
        def angle_max
          @angle_max ||= if max_value
                           max_value.to_f
                         else
                           rows.flat_map { |row| series_entries.map { |e| row[e.data_key].to_f } }
                               .max&.nonzero? || 1
                         end
        end

        def sweep(value)
          (value.to_f / angle_max) * (end_angle - start_angle)
        end

        # Clip a stacked segment's end at end_angle (recharts clips the
        # overflow when the stack runs past the domain max).
        def clip_angle(angle)
          Polar.sign(end_angle - start_angle).positive? ? [angle, end_angle.to_f].min : [angle, end_angle.to_f].max
        end

        Segment = Data.define(:index, :name, :value, :fill, :path, :ring_inner, :ring_outer,
                              :seg_start, :seg_end)

        # Per-series segments: unstacked series sweep from start_angle;
        # stacked series continue from the previous series' end.
        def segments(entry)
          @segments ||= {}
          @segments[entry.data_key] ||= rows.each_with_index.map do |row, i|
            ring_inner, ring_outer = ring(i)
            base = @segment_cursor&.dig(entry.stack, i) || start_angle.to_f
            seg_start = entry.stack ? base : start_angle.to_f
            seg_end = seg_start + sweep(row[entry.data_key])
            seg_end = clip_angle(seg_end) if entry.stack
            if entry.stack
              @segment_cursor ||= {}
              (@segment_cursor[entry.stack] ||= {})[i] = seg_end
            end

            Segment.new(
              index: i,
              name: row[name_key].to_s,
              value: row[entry.data_key],
              fill: segment_fill(entry, row),
              path: Polar.sector_path_with_corners(cx: cx, cy: cy, inner_radius: ring_inner,
                                                   outer_radius: ring_outer, start_angle: seg_start,
                                                   end_angle: seg_end, corner_radius: entry.corner_radius),
              ring_inner: ring_inner,
              ring_outer: ring_outer,
              seg_start: seg_start,
              seg_end: seg_end
            )
          end
        end

        def background_path(segment)
          Polar.sector_path(cx: cx, cy: cy, inner_radius: segment.ring_inner,
                            outer_radius: segment.ring_outer,
                            start_angle: start_angle, end_angle: end_angle)
        end

        def segment_fill(entry, row)
          color = row[entry.color_key].to_s if entry.color_key
          if color.present?
            raise ArgumentError, "radial fill #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

            color
          else
            chart_config[entry.data_key]&.color || "var(--color-#{entry.data_key})"
          end
        end

        # insideStart labels: a FIXED ARC LENGTH into the sweep (not a fixed
        # angle), so an inner ring - where the same ~9px arc spans a larger
        # angle - tilts more, tapering to near-flat on the outer rings, the
        # recharts insideStart look. Rotated onto the arc's TANGENT pointing
        # into the sweep: SVG rotate() is clockwise-positive in the y-down
        # plane, so the tangent at chart angle t is (-sin t, -cos t) for a
        # CCW sweep. (90 - angle reads plausibly but points the text the
        # OPPOSITE way: mirrored and upside down.) When the tangent would
        # still leave the text inverted, flip it 180 and anchor the END at
        # the start edge - recharts' readability flip.
        LABEL_ARC = 9.0

        def label_placement(segment)
          direction = Polar.sign(end_angle - start_angle)
          radius = (segment.ring_inner + segment.ring_outer) / 2.0
          angle = segment.seg_start + (direction * (LABEL_ARC / radius) / Polar::RADIAN)
          x, y = Polar.polar_to_cartesian(cx, cy, radius, angle)
          rad = Polar::RADIAN * angle
          rotate = Math.atan2(-direction * Math.cos(rad), -direction * Math.sin(rad)) / Polar::RADIAN
          anchor = "start"
          if rotate > 90 || rotate <= -90
            rotate -= 180 * Polar.sign(rotate)
            anchor = "end"
          end
          { x: x, y: y, rotate: rotate, anchor: anchor }
        end

        def grid_radii
          config_radii = polar_grid_config[:radii]
          return config_radii if config_radii

          # Auto: circles through each ring's CENTERLINE (recharts' radius
          # band ticks) - each circle continues a bar's track through the
          # uncovered wedge.
          (0...rows.length).map { |i| ring(i).sum / 2.0 }
        end

        # d3.ticks over the value domain (count 10) - recharts' implicit
        # PolarAngleAxis, where the grid's radial spokes sit.
        def angle_tick_values
          max = angle_max.to_f
          return [] unless max.positive?

          step0 = max / 10.0
          power = 10.0**Math.log10(step0).floor
          error = step0 / power
          step = if error >= Math.sqrt(50) then power * 10
                 elsif error >= Math.sqrt(10) then power * 5
                 elsif error >= Math.sqrt(2) then power * 2
                 else power
                 end
          (0..(max / step).floor).map { |i| i * step }
        end

        # A grid spoke at one value tick, spanning the chart's radial band
        # (template helper - bare Polar does not resolve from compiled ERB).
        def spoke_points(tick)
          inner, outer = radii
          angle = start_angle + sweep(tick)
          Polar.polar_to_cartesian(cx, cy, inner, angle) + Polar.polar_to_cartesian(cx, cy, outer, angle)
        end

        def grid_fill_class(index)
          token = polar_grid_config[:fills][index]
          token ? css(:"grid_fill_#{token}") : css(:grid_circle)
        end

        # -- the tooltip payload (polar shape, ring anchors) -------------------

        def coordinates_json
          entry = series_entries.first
          return "{}" unless entry

          primary = segments(entry)
          {
            "layout" => "polar",
            "categories" => primary.map { |s| chart_config.label_for(s.name, s.name) },
            "names" => primary.map { |s| chart_config.label_for(s.name, s.name) },
            "colors" => primary.map(&:fill),
            "anchors" => primary.map do |s|
              Polar.polar_to_cartesian(cx, cy, (s.ring_inner + s.ring_outer) / 2.0,
                                       (s.seg_start + s.seg_end) / 2.0).map { |v| v.round(2) }
            end,
            "values" => { entry.data_key => rows.map { |row| Poetry::Charts.display_value(row[entry.data_key]) } }
          }.to_json
        end

        def chart_id
          @chart_id ||= "chart-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def svg_label
          label.presence || "Radial bar chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        def svg_interaction_attributes
          attributes = super
          if tooltip?
            attributes["data-action"] = "#{attributes["data-action"]} pointerover->#{TooltipWiring::CONTROLLER}#enter"
          end
          attributes
        end

        def tooltip_layer_component
          TooltipLayer::Component.new(
            config: chart_config,
            series_keys: [series_entries.first&.data_key].compact,
            indicator: tooltip_config.fetch(:indicator, :dot),
            hide_label: tooltip_config.fetch(:hide_label, true),
            hide_indicator: tooltip_config.fetch(:hide_indicator, false)
          )
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end
      end
    end
  end
end
