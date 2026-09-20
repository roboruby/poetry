# frozen_string_literal: true

require "test_helper"
require_relative "fixtures_helper"

module Poetry
  module Charts
    module Geometry
      # Stack series against the d3 oracle: plain stacking, percent
      # (expand), and diverging (negatives below the axis).
      class StackTest < ActiveSupport::TestCase
        include FixturesHelper

        def stack_rows(raw)
          raw.map { |row| row.transform_keys(&:to_s) }
        end

        def assert_stack_matches(kase, data)
          series = Stack.new(keys: kase["keys"], offset: kase["offset"].to_sym).series(data)

          kase["expected"].each_with_index do |want, i|
            got = series[i]

            assert_equal want["key"], got.key, "#{kase["offset"]}: series #{i} key"
            assert_equal want["index"], got.index, "#{kase["offset"]}: series #{i} index"
            want["points"].each_with_index do |(lo, hi), j|
              assert_equal lo, got.points[j][0], "#{kase["offset"]}: #{want["key"]}[#{j}] base"
              assert_equal hi, got.points[j][1], "#{kase["offset"]}: #{want["key"]}[#{j}] top"
            end
          end
        end

        def test_offsets_match_d3
          data = stack_rows(fixtures["stack_data"])

          fixtures["stack"].each { |kase| assert_stack_matches(kase, data) }
        end

        def test_diverging_data_matches_d3_across_offsets
          data = stack_rows(fixtures["stack_diverging_data"])

          fixtures["stack_diverging"].each { |kase| assert_stack_matches(kase, data) }
        end

        def test_missing_values_stack_like_js_nan
          data = [{ "a" => 1, "b" => 2 }, { "a" => 3 }] # b missing in row 2
          series = Stack.new(keys: %w[a b]).series(data)

          assert_predicate series[1].points[1][1], :nan?, "missing value tops stay NaN"
          assert_equal 3, series[1].points[1][0], "the NEXT series bases on the previous base when top is NaN"
        end
      end
    end
  end
end
