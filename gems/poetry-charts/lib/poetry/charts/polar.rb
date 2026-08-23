# frozen_string_literal: true

module Poetry
  module Charts
    # The polar geometry: recharts' OWN math, ported from source -
    # this is the part that is NOT d3 (src/util/PolarUtils.ts,
    # src/shape/Sector.tsx getSectorPath, src/polar/Pie.tsx sector
    # accumulation). Angles are degrees COUNTERCLOCKWISE from 3 o'clock,
    # negated into SVG's y-down plane by polar_to_cartesian; pies start at
    # startAngle 0 and sweep to endAngle 360.
    #
    # @example Slice values into pie sector angles
    #   Poetry::Charts::Polar.pie_sectors([3, 1], padding_angle: 2)
    module Polar
      RADIAN = Math::PI / 180

      module_function

      def sign(value)
        return 0 if value.zero?

        value.negative? ? -1 : 1
      end

      def polar_to_cartesian(cx, cy, radius, angle)
        [cx + (Math.cos(-RADIAN * angle) * radius), cy + (Math.sin(-RADIAN * angle) * radius)]
      end

      def max_radius(width, height)
        [width, height].min / 2.0
      end

      # "80%" of the max radius, or a plain number (recharts getPercentValue).
      def percent_value(value, total, default = 0)
        return default if value.nil?

        text = value.to_s
        text.end_with?("%") ? total * (text.to_f / 100.0) : text.to_f
      end

      # The Pie accumulation (Pie.tsx): values -> per-slice angles. Zero
      # values collapse (and skip padding); paddings live BETWEEN non-zero
      # slices (full circles pad after the last slice too, closing the ring).
      def pie_sectors(values, start_angle: 0, end_angle: 360, padding_angle: 0, min_angle: 0)
        numeric = values.map { |value| value.is_a?(Numeric) ? value.to_f : 0.0 }
        sum = numeric.sum
        return [] if sum <= 0

        delta = sign(end_angle - start_angle) * [(end_angle - start_angle).abs, 360].min
        abs_delta = delta.abs
        direction = sign(delta)
        not_zero = numeric.count { |value| !value.zero? }
        total_padding = (abs_delta >= 360 ? not_zero : [not_zero - 1, 0].max) * padding_angle

        needs_min = min_angle.positive? &&
                    numeric.any? { |value| !value.zero? && (value / sum) * abs_delta < min_angle }
        effective_min = needs_min ? min_angle : 0

        real_total = abs_delta - (not_zero * effective_min) - total_padding

        cursor = start_angle.to_f
        numeric.each_with_index.map do |value, i|
          percent = value / sum
          slice_start = if i.zero?
                          start_angle.to_f
                        else
                          cursor + (direction * padding_angle * (value.zero? ? 0 : 1))
                        end
          slice_end = slice_start + (direction * ((value.zero? ? 0 : effective_min) + (percent * real_total)))
          cursor = slice_end

          {
            value: value,
            percent: percent,
            start_angle: slice_start,
            end_angle: slice_end,
            mid_angle: (slice_start + slice_end) / 2.0
          }
        end
      end

      # getTangentCircle (Sector.tsx): the corner circle tangent to an arc
      # (at `radius`) and a radial edge (at `angle`) - the rounded-corner
      # primitive for RadialBar's cornerRadius.
      def tangent_circle(cx:, cy:, radius:, angle:, sign:, corner_radius:, external: false)
        center_radius = (corner_radius * (external ? 1 : -1)) + radius
        theta = Math.asin(corner_radius / center_radius) / RADIAN
        center_angle = angle + (sign * theta)
        {
          circle_tangency: polar_to_cartesian(cx, cy, radius, center_angle),
          line_tangency: polar_to_cartesian(cx, cy, center_radius * Math.cos(theta * RADIAN), angle),
          theta: theta
        }
      end

      # getSectorWithCorner (Sector.tsx): the ring segment with all four
      # corners rounded by tangent circles. Falls back to the plain path
      # when the sweep is too small to fit the corners (recharts' guard).
      def sector_path_with_corners(cx:, cy:, inner_radius:, outer_radius:, start_angle:, end_angle:,
                                   corner_radius:, fmt: nil)
        fmt ||= ->(v) { Geometry.js_number((v * 10_000).round / 10_000.0) }
        corner = [corner_radius.to_f, (outer_radius - inner_radius).abs / 2.0].min
        if corner <= 0 || (end_angle - start_angle).abs >= 360
          return sector_path(cx:, cy:, inner_radius:, outer_radius:, start_angle:, end_angle:, fmt:)
        end

        s = sign(end_angle - start_angle)
        so = tangent_circle(cx:, cy:, radius: outer_radius, angle: start_angle, sign: s, corner_radius: corner)
        eo = tangent_circle(cx:, cy:, radius: outer_radius, angle: end_angle, sign: -s, corner_radius: corner)
        outer_arc = (start_angle - end_angle).abs - so[:theta] - eo[:theta]
        if outer_arc.negative?
          return sector_path(cx:, cy:, inner_radius:, outer_radius:, start_angle:, end_angle:, fmt:)
        end

        ccw = s.negative? ? 1 : 0
        p = ->(point) { "#{fmt.call(point[0])},#{fmt.call(point[1])}" }
        path = "M#{p.call(so[:line_tangency])}" \
               "A#{fmt.call(corner)},#{fmt.call(corner)},0,0,#{ccw},#{p.call(so[:circle_tangency])}" \
               "A#{fmt.call(outer_radius)},#{fmt.call(outer_radius)},0,#{outer_arc > 180 ? 1 : 0},#{ccw}," \
               "#{p.call(eo[:circle_tangency])}" \
               "A#{fmt.call(corner)},#{fmt.call(corner)},0,0,#{ccw},#{p.call(eo[:line_tangency])}"

        if inner_radius.positive?
          si = tangent_circle(cx:, cy:, radius: inner_radius, angle: start_angle, sign: s,
                              corner_radius: corner, external: true)
          ei = tangent_circle(cx:, cy:, radius: inner_radius, angle: end_angle, sign: -s,
                              corner_radius: corner, external: true)
          inner_arc = (start_angle - end_angle).abs - si[:theta] - ei[:theta]
          return "#{path}L#{fmt.call(cx)},#{fmt.call(cy)}Z" if inner_arc.negative? && corner.zero?

          path << "L#{p.call(ei[:line_tangency])}" \
                  "A#{fmt.call(corner)},#{fmt.call(corner)},0,0,#{ccw},#{p.call(ei[:circle_tangency])}" \
                  "A#{fmt.call(inner_radius)},#{fmt.call(inner_radius)},0,#{inner_arc > 180 ? 1 : 0}," \
                  "#{s.positive? ? 1 : 0},#{p.call(si[:circle_tangency])}" \
                  "A#{fmt.call(corner)},#{fmt.call(corner)},0,0,#{ccw},#{p.call(si[:line_tangency])}Z"
        else
          path << "L#{fmt.call(cx)},#{fmt.call(cy)}Z"
        end

        path
      end

      # getSectorPath (Sector.tsx): the wedge/ring path. The delta clamps at
      # 359.999 so a full circle's endpoints never coincide.
      def sector_path(cx:, cy:, inner_radius:, outer_radius:, start_angle:, end_angle:, fmt: nil)
        # 4-decimal precision: a full circle's 359.999-degree endpoints
        # differ only past the 2nd decimal - rounding coarser would collapse
        # them and erase the arc.
        fmt ||= ->(v) { Geometry.js_number((v * 10_000).round / 10_000.0) }
        delta = sign(end_angle - start_angle) * [(end_angle - start_angle).abs, 359.999].min
        temp_end = start_angle + delta
        large = (delta.abs > 180 ? 1 : 0)

        ox0, oy0 = polar_to_cartesian(cx, cy, outer_radius, start_angle)
        ox1, oy1 = polar_to_cartesian(cx, cy, outer_radius, temp_end)

        path = "M#{fmt.call(ox0)},#{fmt.call(oy0)}" \
               "A#{fmt.call(outer_radius)},#{fmt.call(outer_radius)},0," \
               "#{large},#{start_angle > temp_end ? 1 : 0},#{fmt.call(ox1)},#{fmt.call(oy1)}"

        if inner_radius.positive?
          ix0, iy0 = polar_to_cartesian(cx, cy, inner_radius, start_angle)
          ix1, iy1 = polar_to_cartesian(cx, cy, inner_radius, temp_end)
          path << "L#{fmt.call(ix1)},#{fmt.call(iy1)}" \
                  "A#{fmt.call(inner_radius)},#{fmt.call(inner_radius)},0," \
                  "#{large},#{start_angle <= temp_end ? 1 : 0},#{fmt.call(ix0)},#{fmt.call(iy0)}Z"
        else
          path << "L#{fmt.call(cx)},#{fmt.call(cy)}Z"
        end

        path
      end
    end
  end
end
