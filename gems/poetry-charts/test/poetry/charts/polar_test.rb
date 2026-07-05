# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The polar math, characterized against recharts' semantics: angles
    # counterclockwise from 3 o'clock (negated into SVG's y-down plane),
    # pies sweep 0 -> 360, sectors clamp at 359.999 so full circles never
    # collapse, zero slices vanish without padding.
    class PolarTest < ActiveSupport::TestCase
      def test_polar_to_cartesian_is_counterclockwise_from_three_oclock
        x, y = Polar.polar_to_cartesian(0, 0, 100, 0)

        assert_in_delta 100, x, 1e-9
        assert_in_delta 0, y, 1e-9

        x, y = Polar.polar_to_cartesian(0, 0, 100, 90)

        assert_in_delta 0, x, 1e-9
        assert_in_delta(-100, y, 1e-9, "90deg points UP (SVG y-down negation)")
      end

      def test_pie_sectors_split_proportionally_over_the_full_circle
        sectors = Polar.pie_sectors([1, 1, 2])

        assert_equal([0, 90, 180], sectors.map { |s| s[:start_angle] })
        assert_equal([90, 180, 360], sectors.map { |s| s[:end_angle] })
        assert_in_delta 0.25, sectors[0][:percent], 1e-9
        assert_in_delta 45, sectors[0][:mid_angle], 1e-9
      end

      def test_zero_values_collapse_without_consuming_padding
        sectors = Polar.pie_sectors([1, 0, 1], padding_angle: 10)

        assert_equal sectors[1][:start_angle], sectors[1][:end_angle], "zero slices have no sweep"
        # Full circle with 2 non-zero slices: 2 paddings, 340 degrees split evenly.
        assert_in_delta 170, sectors[0][:end_angle] - sectors[0][:start_angle], 1e-9
      end

      def test_sector_path_shapes
        wedge = Polar.sector_path(cx: 100, cy: 100, inner_radius: 0, outer_radius: 50,
                                  start_angle: 0, end_angle: 90)

        assert wedge.start_with?("M150,100"), "starts at 3 o'clock on the outer radius"
        assert_includes wedge, "A50,50,0,0,0,"
        assert wedge.end_with?("L100,100Z"), "wedges close through the center"

        ring = Polar.sector_path(cx: 100, cy: 100, inner_radius: 30, outer_radius: 50,
                                 start_angle: 0, end_angle: 180)

        assert_equal 2, ring.scan("A").length, "rings arc both radii"
        assert_includes ring, "A30,30,0,0,1,", "the inner arc sweeps back"
      end

      def test_full_circle_endpoints_never_coincide
        path = Polar.sector_path(cx: 0, cy: 0, inner_radius: 0, outer_radius: 10,
                                 start_angle: 0, end_angle: 360)

        assert_includes path, "A10,10,0,1,0,", "the large-arc flag engages"
        assert_includes path, "10,0.0002", "359.999 keeps the endpoints measurably apart at 4dp"
      end

      def test_percent_values_resolve
        assert_in_delta 140, Polar.percent_value("80%", 175), 1e-9
        assert_in_delta 60, Polar.percent_value(60, 175), 1e-9
        assert_in_delta 999, Polar.percent_value(nil, 175, 999), 1e-9
      end
    end
  end
end
