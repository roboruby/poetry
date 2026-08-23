# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      module Scale
        # d3-scale scaleLinear (src/linear.js + continuous.js), reduced to
        # the closed poetry surface: a two-point numeric domain/range with
        # bimap normalization (descending domains supported), ticks via
        # Geometry::Ticks, and the linearish nice() domain extension.
        # Degenerate domains map every input to the range midpoint (the d3
        # normalize() contract).
        #
        # @example Map a value into an inverted pixel range
        #   Poetry::Charts::Geometry::Scale::Linear
        #     .new(domain: [0, 100], range: [300, 5]).call(50)
        class Linear
          attr_reader :domain, :range

          def initialize(domain: [0.0, 1.0], range: [0.0, 1.0])
            @domain = domain.map(&:to_f)
            @range = range.map(&:to_f)
          end

          def call(value)
            value = value.to_f
            d0, d1 = domain
            r0, r1 = range

            # bimap: descending domains swap both sides.
            if d1 < d0
              d0, d1 = d1, d0
              r0, r1 = r1, r0
            end

            t = normalize(value, d0, d1)
            r0 + ((r1 - r0) * t)
          end
          alias [] call

          def invert(value)
            value = value.to_f
            d0, d1 = domain
            r0, r1 = range

            if d1 < d0
              d0, d1 = d1, d0
              r0, r1 = r1, r0
            end

            t = normalize(value, r0, r1)
            d0 + ((d1 - d0) * t)
          end

          def ticks(count = 10)
            Ticks.ticks(domain.first, domain.last, count)
          end

          # linearish nice() (d3-scale src/linear.js): extend the domain to
          # tick-increment boundaries, iterating until the increment is
          # stable. Returns a NEW scale (poetry immutability).
          def nice(count = 10)
            d = domain.dup
            i0 = 0
            i1 = d.length - 1
            start = d[i0]
            stop = d[i1]
            prestep = nil
            max_iter = 10

            if stop < start
              start, stop = stop, start
              i0, i1 = i1, i0
            end

            while max_iter.positive?
              max_iter -= 1
              step = Ticks.tick_increment(start, stop, count)
              if step == prestep
                d[i0] = start
                d[i1] = stop
                break
              elsif step.positive?
                start = (start / step).floor * step
                stop = (stop / step).ceil * step
              elsif step.negative? && step.finite?
                start = (start * step).ceil / step
                stop = (stop * step).floor / step
              else
                # Degenerate domain (zero span): JS churns NaN until maxIter
                # and leaves the domain unchanged; bail with the same result.
                break
              end
              prestep = step
            end

            self.class.new(domain: d, range: range)
          end

          private

          # d3 normalize(): a degenerate domain maps everything to t = 0.5.
          def normalize(value, from, to)
            span = to - from
            return span.nan? ? Float::NAN : 0.5 if span.zero?

            (value - from) / span
          end
        end
      end
    end
  end
end
