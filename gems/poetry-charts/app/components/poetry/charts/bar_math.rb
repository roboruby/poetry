# frozen_string_literal: true

module Poetry
  module Charts
    # The bar geometry shared by BarChart and ComposedChart: the slot
    # math dividing each category band (no explicit bar size - stacked
    # bars share a slot, groups sit side by side inside the band), the
    # per-corner rounded rect path, and the entrance origin. Hosts
    # provide cartesian, data, horizontal?, fnum, bar_gap, and
    # bar_category_gap.
    # @api private
    module BarMath
      # One {offset, size} slot per stack group, laid out inside the
      # category band.
      def bar_slots_for(entries)
        groups = entries.map(&:stack_or_self).uniq
        band = cartesian.band_width
        gap = bar_gap.to_f
        trim = bar_percent_value(bar_category_gap, band)
        gap = 0.0 if band - (2 * trim) - ((groups.length - 1) * gap) <= 0

        size = (band - (2 * trim) - ((groups.length - 1) * gap)) / groups.length
        size = Geometry.js_round(size).to_f if size > 1

        groups.each_with_index.to_h do |group, i|
          [group, { offset: trim + ((size + gap) * i), size: size }]
        end
      end

      # One rect per category for a series: band position + slot offset
      # along the category side, the value span on the other, normalized
      # so width/height stay positive (negatives keep the zero edge).
      def bar_cells(entry, slot)
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
      # orientation - stacked segments grow from their own zero-side
      # edge, not the axis baseline.
      def motion_origin(cell)
        if horizontal?
          cell[:value].negative? ? "right" : "left"
        else
          cell[:value].negative? ? "top" : "bottom"
        end
      end

      # radius: Integer (all corners) or [tl, tr, br, bl] (the stacked
      # blocks). Clamped to half the rect so corners never cross.
      def bar_path_for(radius, cell)
        radii = radius.is_a?(Array) ? radius.map(&:to_f) : Array.new(4, radius.to_f)
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

      # Percent-or-pixels: "10%" resolves against the total, a bare
      # number is pixels.
      def bar_percent_value(value, total)
        text = value.to_s
        text.end_with?("%") ? total * (text.to_f / 100.0) : text.to_f
      end
    end
  end
end
