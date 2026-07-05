# frozen_string_literal: true

require "bigdecimal"

module Poetry
  module Charts
    module Geometry
      # recharts' nice-ticks algorithm (src/util/scale/getNiceTickValues.ts +
      # util/arithmetic.ts, v3.9.2), ported to BigDecimal - the plan's
      # "decimal-exact nice ticks". decimal.js-light maps as: new Decimal(x)
      # -> BigDecimal(x.to_s) (both construct from the double's shortest
      # string), mod -> #remainder (truncated, sign of dividend), div ->
      # #div(x, 20) (decimal.js-light's default 20 significant digits),
      # log(10)-based digit counts -> BigDecimal#exponent (exact).
      #
      # Oracle: the translated cases from recharts' own
      # test/util/scale/getNiceTickValues.spec.ts.
      module NiceTicks
        PRECISION = 20
        SNAP_STEPS = [1r, 2r, 2.5r, 5r].map { |step| BigDecimal(step, 10) }.freeze

        module_function

        def dec(value)
          value.is_a?(BigDecimal) ? value : BigDecimal(value.to_f.to_s)
        end

        # Digit count: 1 for [1,10), 0 for [0.1,1), -1 for [0.01,0.1)...
        # BigDecimal#exponent IS floor(log10(|v|)) + 1, exactly.
        def digit_count(value)
          return 1 if value.zero?

          dec(value).exponent
        end

        # [start, end) with a fixed decimal step (recharts rangeStep).
        def range_step(start, stop, step)
          num = start
          result = []
          i = 0
          while num < stop && i < 100_000
            result << num.to_f
            num += step
            i += 1
          end
          result
        end

        def valid_interval(min, max)
          min > max ? [max, min] : [min, max]
        end

        # The default step function: amend the rough step to a value that
        # reads well at its order of magnitude.
        def adaptive_step(rough_step, allow_decimals, correction_factor)
          return BigDecimal(0) if rough_step <= 0

          digits = digit_count(rough_step.to_f)
          digit_count_value = BigDecimal(10)**digits
          step_ratio = rough_step.div(digit_count_value, PRECISION)
          step_ratio_scale = digits == 1 ? BigDecimal("0.1") : BigDecimal("0.05")
          amend_step_ratio = (BigDecimal(step_ratio.div(step_ratio_scale, PRECISION).to_f.ceil) +
                              correction_factor) * step_ratio_scale
          format_step = amend_step_ratio * digit_count_value

          allow_decimals ? BigDecimal(format_step.to_f.to_s) : BigDecimal(format_step.to_f.ceil)
        end

        # The opt-in snap125 step: snap to 1 / 2 / 2.5 / 5 at each order of
        # magnitude.
        def snap125_step(rough_step, allow_decimals, correction_factor)
          return BigDecimal(0) if rough_step <= 0

          # Math.floor(abs.log(10)) == exponent - 1, exactly.
          exponent = dec(rough_step.to_f).abs.exponent - 1
          magnitude = BigDecimal(10)**exponent
          normalized = rough_step.div(magnitude, PRECISION).to_f

          nice_index = SNAP_STEPS.index { |step| step.to_f >= normalized - 1e-10 }
          if nice_index.nil?
            magnitude *= 10
            nice_index = 0
          end

          nice_index += correction_factor
          if nice_index >= SNAP_STEPS.length
            extra_magnitude = nice_index / SNAP_STEPS.length
            nice_index %= SNAP_STEPS.length
            magnitude *= BigDecimal(10)**extra_magnitude
          end

          format_step = SNAP_STEPS[nice_index] * magnitude
          allow_decimals ? format_step : BigDecimal(format_step.to_f.ceil)
        end

        def step_function(mode)
          mode == :snap125 ? method(:snap125_step) : method(:adaptive_step)
        end

        # Ticks when min == max: center a window of tickCount steps on the value.
        def ticks_of_single_value(value, tick_count, allow_decimals)
          step = BigDecimal(1)
          middle = dec(value)

          if middle.frac.nonzero? && allow_decimals
            abs_value = value.abs
            if abs_value < 1
              step = BigDecimal(10)**(digit_count(value) - 1)
              middle = BigDecimal(middle.div(step, PRECISION).to_f.floor) * step
            elsif abs_value > 1
              middle = BigDecimal(value.floor)
            end
          elsif value.zero?
            middle = BigDecimal((tick_count - 1) / 2)
          elsif !allow_decimals
            middle = BigDecimal(value.floor)
          end

          middle_index = (tick_count - 1) / 2
          Array.new(tick_count) { |i| (middle + (BigDecimal(i - middle_index) * step)).to_f }
        end

        # The step + tick bounds for an interval (recursive: a correction
        # factor grows the step until tickCount ticks cover the interval).
        def calculate_step(min, max, tick_count, allow_decimals, correction_factor = 0, step_fn: method(:adaptive_step))
          unless ((max - min) / (tick_count - 1)).finite?
            return { step: BigDecimal(0), tick_min: BigDecimal(0), tick_max: BigDecimal(0) }
          end

          step = step_fn.call((dec(max) - dec(min)).div(BigDecimal(tick_count - 1), PRECISION),
                              allow_decimals, correction_factor)

          middle = if 0.between?(min, max)
                     BigDecimal(0)
                   else
                     mid = (dec(min) + dec(max)).div(BigDecimal(2), PRECISION)
                     mid - mid.remainder(step)
                   end

          below_count = (middle - dec(min)).div(step, PRECISION).to_f.ceil
          up_count = (dec(max) - middle).div(step, PRECISION).to_f.ceil
          scale_count = below_count + up_count + 1

          if scale_count > tick_count
            return calculate_step(min, max, tick_count, allow_decimals, correction_factor + 1, step_fn:)
          end

          if scale_count < tick_count
            up_count += (tick_count - scale_count) if max.positive?
            below_count += (tick_count - scale_count) unless max.positive?
          end

          {
            step: step,
            tick_min: middle - (BigDecimal(below_count) * step),
            tick_max: middle + (BigDecimal(up_count) * step)
          }
        end

        # Nice ticks for [min, max] - ticks may run OUTSIDE the interval to
        # stay round (recharts getNiceTickValues).
        def nice_ticks(domain, tick_count = 6, allow_decimals: true, mode: :auto)
          min, max = domain
          count = [tick_count, 2].max
          cormin, cormax = valid_interval(min, max)

          if cormin == -Float::INFINITY || cormax == Float::INFINITY
            values = if cormax == Float::INFINITY
                       [cormin] + Array.new(tick_count - 1, Float::INFINITY)
                     else
                       Array.new(tick_count - 1, -Float::INFINITY) + [cormax]
                     end
            return min > max ? values.reverse : values
          end

          return ticks_of_single_value(cormin, tick_count, allow_decimals) if cormin == cormax

          bounds = calculate_step(cormin, cormax, count, allow_decimals, 0, step_fn: step_function(mode))
          values = range_step(bounds[:tick_min],
                              bounds[:tick_max] + (BigDecimal("0.1") * bounds[:step]),
                              bounds[:step])

          min > max ? values.reverse : values
        end

        # Nice-stepped ticks CONSTRAINED to [min, max] (recharts
        # getTickValuesFixedDomain) - the domain boundary always closes the list.
        def fixed_domain_ticks(domain, tick_count, allow_decimals: true, mode: :auto)
          min, max = domain
          cormin, cormax = valid_interval(min, max)

          return [min, max] if cormin == -Float::INFINITY || cormax == Float::INFINITY
          return [cormin] if cormin == cormax

          count = [tick_count, 2].max
          step = step_function(mode).call((dec(cormax) - dec(cormin)).div(BigDecimal(count - 1), PRECISION),
                                          allow_decimals, 0)
          values = range_step(dec(cormin), dec(cormax), step) + [cormax]

          unless allow_decimals
            values = values.map { |value| Geometry.js_round(value) }
            last = values.length - 1
            values = values[0...last] if last.positive? && values[last] == values[last - 1]
          end

          min > max ? values.reverse : values
        end
      end
    end
  end
end
