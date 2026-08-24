# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # The scale namespace: Linear, Band, and Point.
      module Scale
        # A band scale: categorical domain -> evenly stepped positions
        # with inner/outer padding and alignment. Point is band with
        # padding_inner = 1 (bandwidth 0), where padding: drives the
        # outer padding - the axis shape line/area charts position
        # categories with.
        #
        # @example
        #   Poetry::Charts::Geometry::Scale::Band
        #     .new(domain: %w[a b c], range: [0, 300]).positions
        class Band
          attr_reader :domain, :range, :padding_inner, :padding_outer, :align, :step, :bandwidth, :positions

          def initialize(domain:, range:, padding_inner: 0.0, padding_outer: 0.0, align: 0.5, round: false)
            @domain = domain.to_a
            @range = range.map(&:to_f)
            @padding_inner = [1.0, padding_inner.to_f].min
            @padding_outer = padding_outer.to_f
            @align = align.to_f.clamp(0.0, 1.0)
            @round = round
            rescale
          end

          # Convenience for the common single padding: knob - one value
          # sets inner AND outer padding.
          def self.padded(domain:, range:, padding: 0.0, align: 0.5, round: false)
            new(domain:, range:, padding_inner: padding, padding_outer: padding, align:, round:)
          end

          # The band's leading-edge position for a category (nil when the
          # category is unknown).
          def call(value)
            index = domain.index(value)
            index && @positions[index]
          end
          alias [] call

          private

          def rescale
            n = domain.length
            reverse = range[1] < range[0]
            start = reverse ? range[1] : range[0]
            stop = reverse ? range[0] : range[1]

            @step = (stop - start) / [1.0, n - padding_inner + (padding_outer * 2)].max
            @step = @step.floor.to_f if @round
            start += (stop - start - (@step * (n - padding_inner))) * align
            @bandwidth = @step * (1 - padding_inner)
            if @round
              start = Geometry.js_round(start).to_f
              @bandwidth = Geometry.js_round(@bandwidth).to_f
            end

            values = Array.new(n) { |i| start + (@step * i) }
            @positions = reverse ? values.reverse : values
          end
        end

        # A point scale: a band with padding_inner pinned to 1 - every
        # category is a zero-width position, padding: is the outer
        # padding.
        #
        # @example
        #   Poetry::Charts::Geometry::Scale::Point
        #     .new(domain: %w[a b c], range: [0, 300]).positions
        class Point < Band
          def initialize(domain:, range:, padding: 0.0, align: 0.5, round: false)
            super(domain:, range:, padding_inner: 1.0, padding_outer: padding.to_f, align:, round:)
          end
        end
      end
    end
  end
end
