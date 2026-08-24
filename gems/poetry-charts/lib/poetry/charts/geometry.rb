# frozen_string_literal: true

module Poetry
  module Charts
    # The geometry core: the tick, scale, and shape math the charts stand
    # on - array ticks, linear/band/point scales, line/area/curve
    # generators, stack layout, and decimal-exact nice-ticks. Every piece
    # is oracle-tested: committed fixtures
    # (test/support/generate_geometry_fixtures.mjs) pin the expected
    # outputs byte-for-byte, alongside translated spec cases.
    #
    # JS number semantics are part of the contract - path strings must
    # match the fixture output byte-for-byte - so rounding and
    # stringification go through js_round / js_number below, never
    # through Ruby defaults (Ruby rounds half away from zero and prints
    # "80.0"; JS floors x+0.5 and prints "80").
    #
    # @example
    #   Poetry::Charts::Geometry.js_number(80.0) # => "80"
    module Geometry
      module_function

      # JS Math.round: floor(x + 0.5) - differs from Float#round at negative
      # halves (JS rounds -2.5 to -2; Ruby to -3).
      def js_round(value)
        (value + 0.5).floor
      end

      # JS Number#toString for the values that appear in SVG path data:
      # integral doubles print bare ("80", not "80.0"), -0 prints "0", and
      # everything else uses shortest round-trip decimal (Ruby and V8 agree
      # on shortest-repr in the post-rounding magnitude range; the exponent
      # guard covers the sub-1e-4 corner where Ruby switches early).
      def js_number(value)
        return "0" if value.zero?

        integral = value.to_i
        return integral.to_s if value == integral

        text = value.to_s
        return text unless text.include?("e")

        format("%.12f", value).sub(/0+\z/, "").delete_suffix(".")
      end

      # JS truthiness for the curve state machines (the line state flag
      # runs nil | 0 | 1 | NaN): nil, 0, and NaN are falsy.
      def js_truthy?(value)
        return false if value.nil?
        return false if value.is_a?(Float) && value.nan?

        value != 0
      end
    end
  end
end

require_relative "geometry/ticks"
require_relative "geometry/nice_ticks"
require_relative "geometry/scale/linear"
require_relative "geometry/scale/band"
require_relative "geometry/path"
require_relative "geometry/curve"
require_relative "geometry/line"
require_relative "geometry/area"
require_relative "geometry/stack"
