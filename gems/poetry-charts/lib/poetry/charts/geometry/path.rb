# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # d3-path Path (d3-path src/path.js), the subset the shape generators
      # need: moveTo/lineTo/bezierCurveTo/quadraticCurveTo/closePath. Numbers
      # are rounded to `digits` decimals with JS Math.round semantics and
      # stringified as JS does (d3-shape v3 defaults digits to 3) - the
      # contract that makes poetry's path strings byte-equal to d3's.
      # Internal cursor state keeps FULL precision (rounding is
      # output-formatting only, exactly as d3's appendRound).
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

        def move_to(x, y)
          x = x.to_f
          y = y.to_f
          @x0 = @x1 = x
          @y0 = @y1 = y
          @data << "M#{fmt(x)},#{fmt(y)}"
        end

        def line_to(x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "L#{fmt(x)},#{fmt(y)}"
        end

        def quadratic_curve_to(cpx, cpy, x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "Q#{fmt(cpx.to_f)},#{fmt(cpy.to_f)},#{fmt(x)},#{fmt(y)}"
        end

        def bezier_curve_to(cp1x, cp1y, cp2x, cp2y, x, y)
          x = x.to_f
          y = y.to_f
          @x1 = x
          @y1 = y
          @data << "C#{fmt(cp1x.to_f)},#{fmt(cp1y.to_f)},#{fmt(cp2x.to_f)},#{fmt(cp2y.to_f)},#{fmt(x)},#{fmt(y)}"
        end

        def close_path
          return if @x1.nil?

          @x1 = @x0
          @y1 = @y0
          @data << "Z"
        end

        def to_s
          @data
        end

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
