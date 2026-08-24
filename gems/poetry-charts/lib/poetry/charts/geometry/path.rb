# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # The path buffer the shape generators write into: move_to /
      # line_to / bezier_curve_to / quadratic_curve_to / close_path.
      # Numbers are rounded to `digits` decimals with JS Math.round
      # semantics and stringified as JS does (digits defaults to 3) - the
      # contract that keeps poetry's path strings byte-equal to the
      # geometry fixtures. Internal cursor state keeps FULL precision
      # (rounding is output-formatting only).
      #
      # The arc/sector verbs are deliberately absent - polar sector paths
      # are built by Polar, not through this class.
      #
      # @example
      #   path = Path.new
      #   path.move_to(0, 0)
      #   path.line_to(10, 20.5)
      #   path.to_s # => "M0,0L10,20.5"
      class Path
        # @param digits [Integer, nil] output rounding decimals; nil disables
        #   rounding (full-precision output)
        def initialize(digits: 3)
          @x0 = @y0 = @x1 = @y1 = nil
          @data = +""
          @scale = digits.nil? ? nil : 10**digits
        end

        # Starts a new subpath at (x, y).
        def move_to(x, y)
          x = x.to_f
          y = y.to_f
          @x0 = @x1 = x
          @y0 = @y1 = y
          @data << "M#{fmt(x)},#{fmt(y)}"
        end

        # A straight segment to (x, y).
        def line_to(x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "L#{fmt(x)},#{fmt(y)}"
        end

        # A quadratic curve to (x, y) with one control point.
        def quadratic_curve_to(cpx, cpy, x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "Q#{fmt(cpx.to_f)},#{fmt(cpy.to_f)},#{fmt(x)},#{fmt(y)}"
        end

        # A cubic curve to (x, y) with two control points.
        def bezier_curve_to(cp1x, cp1y, cp2x, cp2y, x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "C#{fmt(cp1x.to_f)},#{fmt(cp1y.to_f)},#{fmt(cp2x.to_f)},#{fmt(cp2y.to_f)},#{fmt(x)},#{fmt(y)}"
        end

        # Closes the current subpath back to its start (a no-op before
        # any move).
        def close_path
          return if @x1.nil?

          @x1 = @x0
          @y1 = @y0
          @data << "Z"
        end

        # The accumulated SVG path data.
        def to_s
          @data
        end

        # Whether nothing has been written yet.
        def empty?
          @data.empty?
        end

        private

        def fmt(value)
          value = ((value * @scale) + 0.5).floor / @scale.to_f if @scale
          Geometry.js_number(value)
        end
      end
    end
  end
end
