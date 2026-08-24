# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # Float-exact tick generation: ticks / tick_increment / tick_step.
      # The 1-2-5-10 step selection runs against square-root thresholds,
      # and the inverted-increment encoding (negative inc = divisor)
      # keeps tick values float-exact - a sub-1 step divides by an
      # integer instead of multiplying by a fraction.
      #
      # @example
      #   Poetry::Charts::Geometry::Ticks.ticks(0, 10, 5) # => [0, 2, 4, 6, 8, 10]
      module Ticks
        # The step-10 selection threshold: sqrt(50).
        E10 = Math.sqrt(50)
        # The step-5 selection threshold: sqrt(10).
        E5 = Math.sqrt(10)
        # The step-2 selection threshold: sqrt(2).
        E2 = Math.sqrt(2)

        module_function

        # The [first index, last index, increment] spec for a tick run.
        # @api private
        def tick_spec(start, stop, count)
          step = (stop - start) / [0, count].max.to_f
          # JS runs degenerate inputs (zero span) through its float arithmetic
          # and lands on inc = -Infinity; Ruby's floor would raise on the way.
          # Return the same OBSERVABLE outputs analytically: tickIncrement
          # gives -Infinity, tickStep gives 1/Infinity = 0, and the linearish
          # nice() loop bails via its non-finite guard.
          return [Float::NAN, Float::NAN, -Float::INFINITY] unless step.finite? && step.positive?

          power = Math.log10(step).floor
          error = step / (10.0**power)
          factor = if error >= E10 then 10
                   elsif error >= E5 then 5
                   elsif error >= E2 then 2
                   else 1
                   end

          if power.negative?
            inc = (10.0**-power) / factor
            i1 = Geometry.js_round(start * inc)
            i2 = Geometry.js_round(stop * inc)
            i1 += 1 if i1 / inc < start
            i2 -= 1 if i2 / inc > stop
            inc = -inc
          else
            inc = (10.0**power) * factor
            i1 = Geometry.js_round(start / inc)
            i2 = Geometry.js_round(stop / inc)
            i1 += 1 if i1 * inc < start
            i2 -= 1 if i2 * inc > stop
          end

          return tick_spec(start, stop, count * 2) if i2 < i1 && count >= 0.5 && count < 2

          [i1, i2, inc]
        end

        # About `count` evenly stepped, float-exact values covering
        # [start, stop].
        #
        # @return [Array<Numeric>]
        def ticks(start, stop, count)
          start = start.to_f
          stop = stop.to_f
          count = count.to_f
          return [] unless count.positive?
          return [start] if start == stop

          reverse = stop < start
          i1, i2, inc = reverse ? tick_spec(stop, start, count) : tick_spec(start, stop, count)
          return [] if i2 < i1

          n = i2 - i1 + 1
          Array.new(n) do |i|
            index = reverse ? i2 - i : i1 + i
            inc.negative? ? index / -inc : index * inc
          end
        end

        # The raw increment for the run - negative encodes a divisor.
        def tick_increment(start, stop, count)
          tick_spec(start.to_f, stop.to_f, count.to_f)[2]
        end

        # The absolute step size for the run (the increment decoded,
        # signed by direction).
        def tick_step(start, stop, count)
          start = start.to_f
          stop = stop.to_f
          count = count.to_f
          reverse = stop < start
          inc = reverse ? tick_increment(stop, start, count) : tick_increment(start, stop, count)
          (reverse ? -1 : 1) * (inc.negative? ? 1.0 / -inc : inc)
        end
      end
    end
  end
end
