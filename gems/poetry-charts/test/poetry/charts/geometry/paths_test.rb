# frozen_string_literal: true

require "test_helper"
require_relative "fixtures_helper"

module Poetry
  module Charts
    module Geometry
      # Line and Area path strings, BYTE-EQUAL to d3-shape across every
      # curve the shadcn blocks use (linear, step x3, natural, monotoneX),
      # including defined-gap subpaths. String equality is the whole point:
      # rounding (JS Math.round at 3 digits) and number formatting (bare
      # integers, shortest floats) are part of the ported contract.
      class PathsTest < ActiveSupport::TestCase
        include FixturesHelper

        GAP = ->(_d, i) { i != 2 }

        def points(name)
          fixtures["point_sets"].fetch(name)
        end

        def test_line_paths_are_byte_equal_to_d3
          fixtures["line_paths"].each do |kase|
            actual = Line.new(curve: kase["curve"]).path(points(kase["points"]))

            assert_equal kase["expected"], actual, "line #{kase["curve"]} over #{kase["points"]}"
          end
        end

        def test_line_paths_with_defined_gaps_are_byte_equal_to_d3
          fixtures["line_paths_gap"].each do |kase|
            actual = Line.new(curve: kase["curve"], defined: GAP).path(points(kase["points"]))

            assert_equal kase["expected"], actual, "gap line #{kase["curve"]}"
          end
        end

        def test_area_paths_are_byte_equal_to_d3
          fixtures["area_paths"].each do |kase|
            actual = Area.new(y0: 120, y1: ->(d, _i) { d[1] }, curve: kase["curve"]).path(points(kase["points"]))

            assert_equal kase["expected"], actual, "area #{kase["curve"]} over #{kase["points"]}"
          end
        end

        def test_area_paths_with_defined_gaps_are_byte_equal_to_d3
          fixtures["area_paths_gap"].each do |kase|
            actual = Area.new(y0: 120, y1: ->(d, _i) { d[1] }, curve: kase["curve"], defined: GAP)
                         .path(points(kase["points"]))

            assert_equal kase["expected"], actual, "gap area #{kase["curve"]}"
          end
        end

        def test_empty_data_returns_nil
          assert_nil Line.new.path([])
          assert_nil Area.new.path([])
        end

        def test_symbol_accessors_read_hashes
          data = [{ x: 0, y: 10 }, { x: 50, y: 20 }]
          actual = Line.new(x: :x, y: :y).path(data)

          assert_equal "M0,10L50,20", actual
        end
      end
    end
  end
end
