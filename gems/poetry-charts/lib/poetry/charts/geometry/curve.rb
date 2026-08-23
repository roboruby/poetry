# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # The d3-shape curve state machines (src/curve/{linear,step,natural,
      # monotone}.js), transcribed exactly - including the `_line`
      # undefined/0/1/NaN dance that decides where subpaths close (JS
      # truthiness via Geometry.js_truthy?; `1 - undefined` becomes NaN via
      # js_flip). The shadcn blocks use exactly this set: linear, step
      # (+before/after), natural, and monotoneX (recharts' "monotone").
      #
      # @example Build a curve writing into a fresh path buffer
      #   Poetry::Charts::Geometry::Curve.build(:natural, Path.new)
      module Curve
        REGISTRY = {
          linear: ->(context) { Linear.new(context) },
          step: ->(context) { Step.new(context, 0.5) },
          step_before: ->(context) { Step.new(context, 0.0) },
          step_after: ->(context) { Step.new(context, 1.0) },
          natural: ->(context) { Natural.new(context) },
          monotone_x: ->(context) { MonotoneX.new(context) }
        }.freeze

        module_function

        def build(name, context)
          builder = REGISTRY[name.to_sym] or
            raise ArgumentError, "unknown curve #{name.inspect} (one of #{REGISTRY.keys.join(", ")})"
          builder.call(context)
        end

        # JS `1 - line` where line may be undefined (nil) or NaN.
        def self.js_flip(line)
          return Float::NAN if line.nil? || (line.is_a?(Float) && line.nan?)

          1 - line
        end

        # Shared area/line bookkeeping (identical across all four curves).
        module LineState
          def area_start
            @line = 0
          end

          def area_end
            @line = Float::NAN
          end

          private

          def line_truthy?
            Geometry.js_truthy?(@line)
          end

          # JS: this._line || (this._line !== 0 && <extra>)
          def close_on_line_end?(extra)
            line_truthy? || (@line != 0 && extra)
          end

          def flip_line
            @line = Curve.js_flip(@line)
          end
        end

        class Linear
          include LineState

          def initialize(context)
            @context = context
            @line = nil
          end

          def line_start
            @point = 0
          end

          def line_end
            @context.close_path if close_on_line_end?(@point == 1)
            flip_line
          end

          def point(x, y)
            x = x.to_f
            y = y.to_f
            case @point
            when 0
              @point = 1
              line_truthy? ? @context.line_to(x, y) : @context.move_to(x, y)
            else
              @point = 2
              @context.line_to(x, y)
            end
          end
        end

        class Step
          include LineState

          def initialize(context, t)
            @context = context
            @t = t
            @line = nil
          end

          def line_start
            @x = @y = Float::NAN
            @point = 0
          end

          def line_end
            @context.line_to(@x, @y) if @t.positive? && @t < 1 && @point == 2
            @context.close_path if close_on_line_end?(@point == 1)
            # JS: if (this._line >= 0) - false for undefined and NaN.
            return unless !@line.nil? && !(@line.is_a?(Float) && @line.nan?) && @line >= 0

            @t = 1 - @t
            @line = 1 - @line
          end

          def point(x, y)
            x = x.to_f
            y = y.to_f
            case @point
            when 0
              @point = 1
              line_truthy? ? @context.line_to(x, y) : @context.move_to(x, y)
            else
              @point = 2 if @point == 1
              if @t <= 0
                @context.line_to(@x, y)
                @context.line_to(x, y)
              else
                x1 = (@x * (1 - @t)) + (x * @t)
                @context.line_to(x1, @y)
                @context.line_to(x1, y)
              end
            end
            @x = x
            @y = y
          end
        end

        class Natural
          include LineState

          def initialize(context)
            @context = context
            @line = nil
          end

          def line_start
            @xs = []
            @ys = []
          end

          def line_end
            x = @xs
            y = @ys
            n = x.length

            if n.positive?
              line_truthy? ? @context.line_to(x[0], y[0]) : @context.move_to(x[0], y[0])
              if n == 2
                @context.line_to(x[1], y[1])
              elsif n > 2
                px = Natural.control_points(x)
                py = Natural.control_points(y)
                (0...(n - 1)).each do |i0|
                  i1 = i0 + 1
                  @context.bezier_curve_to(px[0][i0], py[0][i0], px[1][i0], py[1][i0], x[i1], y[i1])
                end
              end
            end

            @context.close_path if close_on_line_end?(n == 1)
            flip_line
            @xs = @ys = nil
          end

          def point(x, y)
            @xs << x.to_f
            @ys << y.to_f
          end

          # The tridiagonal control-point solve
          # (https://www.particleincell.com/2012/bezier-splines/).
          def self.control_points(x)
            n = x.length - 1
            a = Array.new(n)
            b = Array.new(n)
            r = Array.new(n)

            a[0] = 0.0
            b[0] = 2.0
            r[0] = x[0] + (2 * x[1])
            (1...(n - 1)).each do |i|
              a[i] = 1.0
              b[i] = 4.0
              r[i] = (4 * x[i]) + (2 * x[i + 1])
            end
            a[n - 1] = 2.0
            b[n - 1] = 7.0
            r[n - 1] = (8 * x[n - 1]) + x[n]

            (1...n).each do |i|
              m = a[i] / b[i - 1]
              b[i] -= m
              r[i] -= m * r[i - 1]
            end

            a[n - 1] = r[n - 1] / b[n - 1]
            (n - 2).downto(0) { |i| a[i] = (r[i] - a[i + 1]) / b[i] }
            b[n - 1] = (x[n] + a[n - 1]) / 2
            (0...(n - 1)).each { |i| b[i] = (2 * x[i + 1]) - a[i + 1] }

            [a, b]
          end
        end

        class MonotoneX
          include LineState

          def initialize(context)
            @context = context
            @line = nil
          end

          def line_start
            @x0 = @x1 = @y0 = @y1 = @t0 = Float::NAN
            @point = 0
          end

          def line_end
            case @point
            when 2 then @context.line_to(@x1, @y1)
            when 3 then emit(@t0, slope2(@t0))
            end
            @context.close_path if close_on_line_end?(@point == 1)
            flip_line
          end

          def point(x, y)
            x = x.to_f
            y = y.to_f
            return if x == @x1 && y == @y1 # ignore coincident points

            case @point
            when 0
              @point = 1
              line_truthy? ? @context.line_to(x, y) : @context.move_to(x, y)
              t1 = Float::NAN
            when 1
              @point = 2
              t1 = Float::NAN
            when 2
              @point = 3
              t1 = slope3(x, y)
              emit(slope2(t1), t1)
            else
              t1 = slope3(x, y)
              emit(@t0, t1)
            end

            @x0 = @x1
            @x1 = x
            @y0 = @y1
            @y1 = y
            @t0 = t1
          end

          private

          def sign(value)
            value.negative? ? -1.0 : 1.0
          end

          # Steffen (1990) monotone tangent slopes. The JS `(h0 || h1 < 0 &&
          # -0)` denominator trick yields signed zero when h0 is 0, so the
          # division produces the correctly signed infinity.
          def slope3(x2, y2)
            h0 = @x1 - @x0
            h1 = x2 - @x1
            d0 = if h0.zero? && !h0.nan?
                   h1.negative? ? -0.0 : 0.0
                 else
                   h0
                 end
            d1 = if h1.zero? && !h1.nan?
                   h0.negative? ? -0.0 : 0.0
                 else
                   h1
                 end
            s0 = (@y1 - @y0) / d0
            s1 = (y2 - @y1) / d1
            p = ((s0 * h1) + (s1 * h0)) / (h0 + h1)
            result = (sign(s0) + sign(s1)) * [s0.abs, s1.abs, 0.5 * p.abs].min
            result.nan? ? 0.0 : result
          end

          def slope2(t)
            h = @x1 - @x0
            Geometry.js_truthy?(h) ? (((3 * (@y1 - @y0)) / h) - t) / 2 : t
          end

          # Hermite -> cubic Bezier (control points at thirds).
          def emit(t0, t1)
            dx = (@x1 - @x0) / 3
            @context.bezier_curve_to(@x0 + dx, @y0 + (dx * t0), @x1 - dx, @y1 - (dx * t1), @x1, @y1)
          end
        end
      end
    end
  end
end
