# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # d3-array ticks/tickIncrement/tickStep (src/ticks.js, v3), ported
      # line-for-line. The 1-2-5-10 step selection against sqrt thresholds
      # and the inverted-increment encoding (negative inc = divisor) are
      # d3's exact trick for float-exact tick values.
      #
      # @example
      #   Poetry::Charts::Geometry::Ticks.ticks(0, 10, 5) # => [0, 2, 4, 6, 8, 10]
      module Ticks
        E10 = Math.sqrt(50)
        E5 = Math.sqrt(10)
        E2 = Math.sqrt(2)

        module_function

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

        def tick_increment(start, stop, count)
          tick_spec(start.to_f, stop.to_f, count.to_f)[2]
        end

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
