# frozen_string_literal: true

module Poetry
  module Charts
    # The radial bar chart family.
    module RadialBarChart
      # Renders a radial bar chart: one angular bar per data row on
      # concentric rings between inner_radius and outer_radius, sweep
      # proportional to value over the angle span. Rings divide the
      # radial band with the SAME math as vertical bars (10% trim, 4px
      # gaps); stacked radial bars share the ring and stack along the
      # ANGLE; corner_radius rounds arc ends with tangent circles;
      # `background: true` draws the muted track ring; polar-grid discs
      # (the gauge look) and the donut-style center label round out the
      # family.
      #
      # @example Rings with track backgrounds and a tooltip
      #   <%= poetry_chart :radial, data: browsers, config: config,
      #                    inner_radius: 30, outer_radius: 110 do |c| %>
      #     <% c.with_radial_bar data_key: :visitors, background: true %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        # Projected into the registry and agent surface.
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

        # One with_radial_bar call's captured series config.
        Series = Data.define(:data_key, :stack, :background, :corner_radius, :color_key,
                             :labels, :label_key)

        # The rows to plot: an array of hashes, one ring per row.
        option :data, ActiveModel::Type::Value.new, required: true
        # The series config - name => { label:, color: } - naming and
        # coloring the rings.
        option :config, ActiveModel::Type::Value.new, required: true
        # Explicit DOM id token, stable across renders; otherwise the
        # chart gets a unique per-render id.
        option :id, :string
        # ViewBox width in pixels; the rendered chart scales to its
        # container.
        option :width, :integer, default: 250
        # ViewBox height in pixels.
        option :height, :integer, default: 250
        # Margin overrides ({ top:, right:, bottom:, left: }), merged
        # over the slim polar default.
        option :margin, ActiveModel::Type::Value.new
        # Accessible name for the chart SVG; defaults to one built from
        # the configured series.
        option :label, :string

        motion_options
        # The row key naming each ring.
        option :name_key, :string, default: "name"
        # Where the sweep starts, in degrees.
        option :start_angle, :integer, default: 0
        # Where the sweep ends - 180 makes a half gauge.
        option :end_angle, :integer, default: 360
        # The innermost ring edge: a percent string of the max radius, or
        # pixels.
        option :inner_radius, ActiveModel::Type::Value.new, default: "20%"
        # The outermost ring edge: a percent string of the max radius, or
        # pixels.
        option :outer_radius, ActiveModel::Type::Value.new, default: "80%"
        # The angle-axis maximum: nil = the largest single value, so the
        # largest ring closes the full sweep EXACTLY (nicing it would
        # leave a notch); stacked gauges pass the stack total when the
        # segments should fill the span.
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

        # A radial series reading data_key: values. background: draws the
        # muted track ring; bars sharing a stack: id share the ring and
        # stack by angle; corner_radius: rounds the arc ends.
        renders_many :radial_bars, lambda { |data_key:, stack: nil, background: false, corner_radius: 0,
                                            color_key: :fill, labels: nil, label_key: nil|
          (@series_entries ||= []) << Series.new(data_key: data_key.to_s, stack:, background:,
                                                 corner_radius:, color_key: color_key&.to_s,
                                                 labels: labels&.to_sym, label_key: label_key&.to_s)
          nil
        }

        # The disc track behind the rings: radii: places the circles
        # (default: each ring's centerline), fills: tints them, and
        # radial_lines: draws the faint value spokes that show through
        # ring gaps and the open wedge (on by default; gauges turn them
        # off).
        renders_one :polar_grid, lambda { |radii: nil, fills: nil, radial_lines: true|
          @polar_grid_config = { radii: radii, fills: Array(fills), radial_lines: radial_lines }
          nil
        }

        # The center text: a title line plus an optional subtitle. The
        # default is the full gauge's big centered number; compact:
        # shrinks it and sits it just above a half gauge's flat baseline.
        renders_one :center_label, lambda { |title:, subtitle: nil, compact: false|
          @center_label_config = { title: title, subtitle: subtitle, compact: compact }
          nil
        }

        # The legend row: align:, items:, and hide_icon:.
        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        # The hover tooltip; the ring name carries the label, so
        # hide_label defaults on.
        renders_one :tooltip, lambda { |**options|
          @tooltip_config = { hide_label: true }.merge(options)
          nil
        }

        # The polar chassis: margin/plot/center geometry plus the per-arc
        # pointerover hit; the single-series tooltip chrome and payload
        # ride the polar_* hooks below.
        include Poetry::Charts::PolarFamily
        include Poetry::Charts::PolarFamily::SingleSeriesTooltip

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          radial_bars? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        # The polar-grid slot's captured config, forcing lazy slot
        # evaluation.
        # @api private
        def polar_grid_config
          polar_grid?
          @polar_grid_config
        end

        # The center-label slot's captured config, forcing lazy slot
        # evaluation.
        # @api private
        def center_label_config
          center_label?
          @center_label_config
        end

        # -- geometry ---------------------------------------------------------

        # Band trim on each side of a ring, as a fraction of the band.
        TRIM = 0.1
        # Pixels between rings.
        GAP = 4.0

        # The data rows with stringified keys.
        # @api private
        def rows
          @rows ||= data.map { |row| row.to_h.transform_keys(&:to_s) }
        end

        # The [inner, outer] radial band edges resolved to pixels.
        # @api private
        def radii
          @radii ||= begin
            max = Polar.max_radius(plot[:width], plot[:height])
            [Polar.percent_value(inner_radius, max, max * 0.2),
             Polar.percent_value(outer_radius, max, max * 0.8)]
          end
        end

        # The radial band: one ring per ROW, the vertical-bar math rotated
        # onto the radius axis (10% trim each side, 4px between rings).
        # @api private
        def ring(index)
          inner, outer = radii
          band = (outer - inner) / rows.length
          trim = band * TRIM
          thickness = band - (2 * trim)
          ring_inner = inner + (band * index) + trim
          [ring_inner, ring_inner + thickness]
        end

        # Whether any series declared a stack.
        # @api private
        def stacked?
          series_entries.any?(&:stack)
        end

        # The default angle domain is [0, max] over the RAW cell values,
        # NOT the stacked totals - so a stacked ring maps each segment
        # through the max single value and the overflow past end_angle is
        # clipped (a half gauge: 570 of max 1260 = 81deg; the next
        # segment stacks on and clips at 180deg). An explicit max_value:
        # overrides (a caller who wants the stack total to fill the span
        # exactly passes it).
        # @api private
        def angle_max
          @angle_max ||= if max_value
                           max_value.to_f
                         else
                           rows.flat_map { |row| series_entries.map { |e| row[e.data_key].to_f } }
                               .max&.nonzero? || 1
                         end
        end

        # A value's angular sweep across the span.
        # @api private
        def sweep(value)
          (value.to_f / angle_max) * (end_angle - start_angle)
        end

        # Clip a stacked segment's end at end_angle - a stack running
        # past the domain max never sweeps beyond the span.
        # @api private
        def clip_angle(angle)
          Polar.sign(end_angle - start_angle).positive? ? [angle, end_angle.to_f].min : [angle, end_angle.to_f].max
        end

        # One computed arc: its ring and sweep geometry plus name, value,
        # and fill.
        Segment = Data.define(:index, :name, :value, :fill, :path, :ring_inner, :ring_outer,
                              :seg_start, :seg_end)

        # Per-series segments: unstacked series sweep from start_angle;
        # stacked series continue from the previous series' end.
        # @api private
        def segments(entry)
          @segments ||= {}
          # Slot-identity memo, never data_key: two series may share a
          # data_key (different stacks), and a key-keyed memo would render
          # the first series' segments twice.
          @segments[entry.object_id] ||= rows.each_with_index.map do |row, i|
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

        # The muted full-span track ring behind one bar.
        # @api private
        def background_path(segment)
          Polar.sector_path(cx: cx, cy: cy, inner_radius: segment.ring_inner,
                            outer_radius: segment.ring_outer,
                            start_angle: start_angle, end_angle: end_angle)
        end

        # A ring's fill: the color_key row value (CSS-validated), else
        # the config color for the series, else the series color var.
        # @api private
        def segment_fill(entry, row)
          color = row[entry.color_key].to_s if entry.color_key
          if color.present?
            raise ArgumentError, "radial fill #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

            color
          else
            chart_config[entry.data_key]&.color || "var(--color-#{entry.data_key})"
          end
        end

        # Inside-start labels sit a FIXED ARC LENGTH into the sweep (not
        # a fixed angle), so an inner ring - where the same ~9px arc
        # spans a larger angle - tilts more, tapering to near-flat on the
        # outer rings. Rotated onto the arc's TANGENT pointing into the
        # sweep: SVG rotate() is clockwise-positive in the y-down plane,
        # so the tangent at chart angle t is (-sin t, -cos t) for a CCW
        # sweep. (90 - angle reads plausibly but points the text the
        # OPPOSITE way: mirrored and upside down.) When the tangent would
        # still leave the text inverted, flip it 180 and anchor the END
        # at the start edge so the label stays readable.
        LABEL_ARC = 9.0

        # One segment's label position, rotation, and anchor.
        # @api private
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

        # The grid circles' radii: the slot's radii:, else auto.
        # @api private
        def grid_radii
          config_radii = polar_grid_config[:radii]
          return config_radii if config_radii

          # Auto: circles through each ring's CENTERLINE - each circle
          # continues a bar's track through the uncovered wedge.
          (0...rows.length).map { |i| ring(i).sum / 2.0 }
        end

        # Standard 1-2-5 ticks over the value domain (count 10) - the
        # implicit angle axis, where the grid's radial spokes sit.
        # @api private
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
        # @api private
        def spoke_points(tick)
          inner, outer = radii
          angle = start_angle + sweep(tick)
          Polar.polar_to_cartesian(cx, cy, inner, angle) + Polar.polar_to_cartesian(cx, cy, outer, angle)
        end

        # One grid circle's class: its fills: tint, else the plain ring.
        # @api private
        def grid_fill_class(index)
          token = polar_grid_config[:fills][index]
          token ? css(:"grid_fill_#{token}") : css(:grid_circle)
        end

        # -- the tooltip payload (polar shape, ring anchors) -------------------

        # The SingleSeriesTooltip hooks: the first series' segments are
        # the items, anchored mid-ring / mid-sweep; values read the chart
        # rows.
        # @api private
        def polar_items(entry) = segments(entry)

        # Where the tooltip anchors on one segment.
        # @api private
        def polar_anchor(segment)
          Polar.polar_to_cartesian(cx, cy, (segment.ring_inner + segment.ring_outer) / 2.0,
                                   (segment.seg_start + segment.seg_end) / 2.0)
        end

        # The rows the tooltip values read from.
        # @api private
        def polar_value_rows(_entry) = rows

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Radial bar chart"
      end
    end
  end
end
