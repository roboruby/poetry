# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # The line generator: data -> SVG path string through a curve state
      # machine, with defined-gaps starting new subpaths (a single toggle
      # loop). Accessors are lambdas (d, i), symbols/strings (hash key
      # lookup), or numeric constants; x/y default to the [x, y] pair
      # convention.
      #
      # @example
      #   Poetry::Charts::Geometry::Line.new(curve: :monotone_x).path(points)
      class Line
        def initialize(x: nil, y: nil, curve: :linear, defined: nil, digits: 3)
          @x = Accessor.wrap(x) { |d, _i| d[0] }
          @y = Accessor.wrap(y) { |d, _i| d[1] }
          @defined = Accessor.wrap(defined) { |_d, _i| true }
          @curve = curve
          @digits = digits
        end

        # The SVG path for the data (nil when nothing was defined).
        #
        # @param data [Enumerable]
        # @return [String, nil]
        def path(data)
          data = data.to_a
          n = data.length
          buffer = Path.new(digits: @digits)
          output = Curve.build(@curve, buffer)
          defined0 = false

          (0..n).each do |i|
            d = i < n ? data[i] : nil
            if (!(i < n && @defined.call(d, i))) == defined0
              defined0 = !defined0
              defined0 ? output.line_start : output.line_end
            end
            output.point(@x.call(d, i).to_f, @y.call(d, i).to_f) if defined0
          end

          buffer.empty? ? nil : buffer.to_s
        end

        # Accessor coercion shared by the generators.
        module Accessor
          module_function

          # A (d, i) lambda from a lambda, key, constant, or the default.
          def wrap(value, &default)
            case value
            when nil then default
            when Proc then value.arity == 1 ? ->(d, _i) { value.call(d) } : value
            when Symbol, String then ->(d, _i) { d[value] }
            when Numeric then ->(_d, _i) { value }
            else raise ArgumentError, "bad accessor #{value.inspect}"
            end
          end
        end
      end
    end
  end
end
