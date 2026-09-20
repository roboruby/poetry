# frozen_string_literal: true

require "test_helper"
require_relative "fixtures_helper"

module Poetry
  module Charts
    module Geometry
      # scaleLinear (mapping + nice + ticks) and scaleBand/scalePoint
      # against the d3 oracle.
      class ScaleTest < ActiveSupport::TestCase
        include FixturesHelper

        def test_linear_mapping_matches_d3
          fixtures["scale_linear"].each do |kase|
            scale = Scale::Linear.new(domain: kase["domain"], range: kase["range"])

            kase["expected"].each do |input, want|
              assert_equal want, scale.call(input),
                           "linear #{kase["domain"]}->#{kase["range"]} at #{input}"
            end
          end
        end

        def test_linear_nice_matches_d3
          fixtures["scale_linear_nice"].each do |kase|
            niced = Scale::Linear.new(domain: kase["domain"], range: [0, 1]).nice(kase["count"])

            assert_numbers_equal kase["expected"], niced.domain,
                                 "nice(#{kase["domain"]}, #{kase["count"]})"
          end
        end

        def test_nice_plus_ticks_matches_the_d3_axis_recipe
          fixtures["nice_ticks_d3"].each do |kase|
            scale = Scale::Linear.new(domain: kase["domain"], range: [0, 1]).nice(kase["count"])

            assert_numbers_equal kase["expected"], scale.ticks(kase["count"]),
                                 "nice+ticks(#{kase["domain"]}, #{kase["count"]})"
          end
        end

        def test_linear_invert_round_trips
          scale = Scale::Linear.new(domain: [0, 97], range: [250, 0])

          assert_in_delta 48.5, scale.invert(scale.call(48.5)), 1e-9
        end

        def test_band_matches_d3
          fixtures["scale_band"].each do |kase|
            scale = Scale::Band.new(domain: kase["domain"], range: kase["range"],
                                    padding_inner: kase["paddingInner"], padding_outer: kase["paddingOuter"],
                                    align: kase["align"])
            expected = kase["expected"]

            assert_equal expected["step"], scale.step, "band step #{kase["domain"]}"
            assert_equal expected["bandwidth"], scale.bandwidth, "band bandwidth #{kase["domain"]}"
            assert_numbers_equal expected["positions"], kase["domain"].map { |v| scale.call(v) },
                                 "band positions #{kase["domain"]}"
          end
        end

        def test_point_matches_d3
          fixtures["scale_point"].each do |kase|
            scale = Scale::Point.new(domain: kase["domain"], range: kase["range"], padding: kase["padding"])
            expected = kase["expected"]

            assert_equal expected["step"], scale.step, "point step #{kase["domain"]}"
            assert_equal 0, scale.bandwidth, "point bandwidth is zero"
            assert_numbers_equal expected["positions"], kase["domain"].map { |v| scale.call(v) },
                                 "point positions #{kase["domain"]}"
          end
        end

        def test_band_returns_nil_for_unknown_values
          scale = Scale::Band.new(domain: %w[a b], range: [0, 100])

          assert_nil scale.call("z")
        end
      end
    end
  end
end
