# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    module Geometry
      # The recharts nice-ticks oracle: every case below is translated
      # 1:1 from recharts' own test/util/scale/getNiceTickValues.spec.ts
      # (v3.9.2) - the porting contract this gem committed to.
      class NiceTicksTest < ActiveSupport::TestCase
        INF = Float::INFINITY

        # getNiceTickValues: [domain, tick_count, allow_decimals, mode] => expected
        NICE_CASES = [
          [[[5, 5], 3], [4, 5, 6]],
          [[[5, 5], 4], [4, 5, 6, 7]],
          [[[-5, -5], 5], [-7, -6, -5, -4, -3]],
          [[[-5, -5], 2], [-5, -4]],
          [[[0, 0], 5], [0, 1, 2, 3, 4]],
          [[[0, 0], 4], [0, 1, 2, 3]],
          [[[0.05, 0.05], 3], [0.04, 0.05, 0.06]],
          [[[0.05, 0.05], 3, false], [-1, 0, 1]],
          [[[0.8, 0.8], 4], [0.7, 0.8, 0.9, 1]],
          [[[5.2, 5.2], 3], [4, 5, 6]],
          [[[5.2, 5.2], 3, false], [4, 5, 6]],
          [[[3.92, 3.92], 2], [3, 4]],
          [[[-0.053, -0.053], 5], [-0.08, -0.07, -0.06, -0.05, -0.04]],
          [[[-0.053, -0.053], 5, false], [-3, -2, -1, 0, 1]],
          [[[-0.832, -0.832], 4], [-1, -0.9, -0.8, -0.7]],
          [[[-5.2, -5.2], 3], [-7, -6, -5]],
          [[[-3.92, -3.92], 2], [-4, -3]],
          [[[INF, INF], 5], [INF, INF, INF, INF, INF]],
          [[[-INF, -INF], 5], [-INF, -INF, -INF, -INF, -INF]],
          [[[1, 5], 5], [1, 2, 3, 4, 5]],
          [[[-5, 95], 7], [-20, 0, 20, 40, 60, 80, 100]],
          [[[-105, -25], 6], [-120, -100, -80, -60, -40, -20]],
          [[[67, 5], 5], [80, 60, 40, 20, 0]],
          [[[67, 5], 4], [75, 50, 25, 0]],
          [[[39.9156, 42.5401], 5], [39.9, 40.6, 41.3, 42, 42.7]],
          [[[0.3885416666666666, 0.04444444444444451], 5], [0.4, 0.3, 0.2, 0.1, 0]],
          [[[-4.10389, 0.59414], 7], [-4.25, -3.4, -2.55, -1.7, -0.85, 0, 0.85]],
          [[[-4.10389, 0.59414], 7, false], [-5, -4, -3, -2, -1, 0, 1]],
          [[[0, 14], 5], [0, 4, 8, 12, 16]],
          [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
          [[[0, 1e100], 6], [0, 2e99, 4e99, 6e99, 8e99, 1e100]],
          [[[-INF, INF], 5], [-INF, INF, INF, INF, INF]],
          [[[-INF, 100], 5], [-INF, -INF, -INF, -INF, 100]],
          [[[-100, INF], 5], [-100, INF, INF, INF, INF]],
          [[[0, 0.000013202017268238587], 5], [0, 0.0000035, 0.000007, 0.0000105, 0.000014]]
        ].freeze

        SNAP_CASES = [
          [[[0, 14], 5], [0, 5, 10, 15, 20]],
          [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
          [[[-5, 95], 7], [-20, 0, 20, 40, 60, 80, 100]],
          [[[-105, -25], 6], [-120, -100, -80, -60, -40, -20]],
          [[[67, 5], 5], [80, 60, 40, 20, 0]],
          [[[1, 5], 5], [1, 2, 3, 4, 5]],
          [[[39.9156, 42.5401], 5], [39, 40, 41, 42, 43]],
          [[[-4.10389, 0.59414], 7], [-5, -4, -3, -2, -1, 0, 1]],
          [[[0, 0.000013202017268238587], 5], [0, 0.000005, 0.00001, 0.000015, 0.00002]],
          [[[0, 1e100], 6], [0, 2e99, 4e99, 6e99, 8e99, 1e100]],
          [[[-1000, 1000], 5], [-1000, -500, 0, 500, 1000]]
        ].freeze

        FIXED_SNAP_CASES = [
          [[[0, 14], 5], [0, 5, 10, 14]],
          [[[0, 1], 5], [0, 0.25, 0.5, 0.75, 1]],
          [[[-5, 95], 7], [-5, 15, 35, 55, 75, 95]],
          [[[0, 100], 6], [0, 20, 40, 60, 80, 100]],
          [[[1, 1000], 5], [1, 251, 501, 751, 1000]]
        ].freeze

        def test_nice_ticks_match_the_recharts_spec
          NICE_CASES.each do |(args, expected)|
            domain, count, allow = args
            actual = NiceTicks.nice_ticks(domain, count, allow_decimals: allow.nil? || allow)

            assert_equal expected, actual, "nice_ticks(#{domain.inspect}, #{count}, #{allow.inspect})"
          end
        end

        def test_snap125_matches_the_recharts_spec
          SNAP_CASES.each do |(args, expected)|
            domain, count = args
            actual = NiceTicks.nice_ticks(domain, count, mode: :snap125)

            assert_equal expected, actual, "snap125 nice_ticks(#{domain.inspect}, #{count})"
          end
        end

        def test_fixed_domain_snap125_matches_the_recharts_spec
          FIXED_SNAP_CASES.each do |(args, expected)|
            domain, count = args
            actual = NiceTicks.fixed_domain_ticks(domain, count, mode: :snap125)

            assert_equal expected, actual, "fixed_domain_ticks(#{domain.inspect}, #{count})"
          end
        end

        def test_single_value_ticks_match_the_recharts_spec
          assert_equal [3, 4, 5, 6, 7], NiceTicks.ticks_of_single_value(5, 5, true)
          assert_equal [3, 4, 5, 6, 7], NiceTicks.ticks_of_single_value(5.5, 5, true)
          assert_equal [3, 4, 5, 6, 7], NiceTicks.ticks_of_single_value(5.5, 5, false)
          assert_equal [0.3, 0.4, 0.5, 0.6, 0.7], NiceTicks.ticks_of_single_value(0.5, 5, true)
          assert_equal [-2, -1, 0, 1, 2], NiceTicks.ticks_of_single_value(0.5, 5, false)
          assert_equal [-1, 0, 1], NiceTicks.ticks_of_single_value(0.5, 3, false)
        end

        def test_adaptive_step_matches_the_recharts_spec
          assert_equal 0, NiceTicks.adaptive_step(BigDecimal("-0.5"), true, 0).to_f
          assert_in_delta(0.5, NiceTicks.adaptive_step(BigDecimal("0.5"), true, 0).to_f)
          assert_in_delta(3.5e9, NiceTicks.adaptive_step(BigDecimal("3.45687e9"), true, 0).to_f)
          assert_in_delta(1e-8, NiceTicks.adaptive_step(BigDecimal("9.6341e-9"), true, 0).to_f)
          assert_equal 1, NiceTicks.adaptive_step(BigDecimal("0.5"), false, 0).to_f
        end

        def test_snap125_step_matches_the_recharts_spec
          assert_equal 0, NiceTicks.snap125_step(BigDecimal("-0.5"), true, 0).to_f
          assert_equal 5, NiceTicks.snap125_step(BigDecimal("3.5"), true, 0).to_f
          assert_in_delta(0.25, NiceTicks.snap125_step(BigDecimal("0.25"), true, 0).to_f)
          assert_in_delta(0.5, NiceTicks.snap125_step(BigDecimal("0.5"), true, 0).to_f)
          assert_equal 10, NiceTicks.snap125_step(BigDecimal("7.3"), true, 0).to_f
          assert_in_delta(5e9, NiceTicks.snap125_step(BigDecimal("3.45687e9"), true, 0).to_f)
          assert_in_delta(1e-8, NiceTicks.snap125_step(BigDecimal("9.6341e-9"), true, 0).to_f)
          assert_equal 1, NiceTicks.snap125_step(BigDecimal("0.5"), false, 0).to_f
        end

        def test_calculate_step_matches_the_recharts_spec
          bounds = NiceTicks.calculate_step(100, 200, 5, true)

          assert_equal 25, bounds[:step].to_f
          assert_equal 100, bounds[:tick_min].to_f
          assert_equal 200, bounds[:tick_max].to_f

          zero_spanning = NiceTicks.calculate_step(-100, 100, 5, true)

          assert_equal 50, zero_spanning[:step].to_f
          assert_equal(-100, zero_spanning[:tick_min].to_f)
          assert_equal 100, zero_spanning[:tick_max].to_f

          degenerate = NiceTicks.calculate_step(Float::INFINITY, Float::INFINITY, 5, true)

          assert_equal 0, degenerate[:step].to_f
        end
      end
    end
  end
end
