# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # d3-shape area() (src/area.js): the filled band between a top line
      # (x/x1, y1) and a baseline (x0, y0), walked forward along the top and
      # BACKWARD along the buffered baseline per defined-segment - the exact
      # d3 loop, including the x0z/y0z buffers. Stacked areas feed y0/y1
      # from Stack series; simple areas use a constant y0 (the axis line).
      class Area
        def initialize(x: nil, x1: nil, y0: nil, y1: nil, curve: :linear, defined: nil, digits: 3)
          @x0 = Line::Accessor.wrap(x) { |d, _i| d[0] }
          @x1 = x1.nil? ? nil : Line::Accessor.wrap(x1) { |d, _i| d[0] }
          @y0 = Line::Accessor.wrap(y0) { |_d, _i| 0.0 }
          @y1 = y1.nil? ? nil : Line::Accessor.wrap(y1) { |d, _i| d[1] }
          @curve = curve
          @digits = digits
          @defined = Line::Accessor.wrap(defined) { |_d, _i| true }
        end

        def path(data)
          data = data.to_a
          n = data.length
          buffer = Path.new(digits: @digits)
          output = Curve.build(@curve, buffer)
          defined0 = false
          x0z = Array.new(n)
          y0z = Array.new(n)
          j = 0

          (0..n).each do |i|
            d = i < n ? data[i] : nil
            if (!(i < n && @defined.call(d, i))) == defined0
              defined0 = !defined0
              if defined0
                j = i
                output.area_start
                output.line_start
              else
                output.line_end
                output.line_start
                (i - 1).downto(j) { |k| output.point(x0z[k], y0z[k]) }
                output.line_end
                output.area_end
              end
            end
            next unless defined0

            x0z[i] = @x0.call(d, i).to_f
            y0z[i] = @y0.call(d, i).to_f
            output.point(@x1 ? @x1.call(d, i).to_f : x0z[i],
                         @y1 ? @y1.call(d, i).to_f : y0z[i])
          end

          buffer.empty? ? nil : buffer.to_s
        end
      end
    end
  end
end
