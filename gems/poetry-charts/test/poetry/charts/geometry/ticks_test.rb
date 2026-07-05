# frozen_string_literal: true

require "test_helper"
require_relative "fixtures_helper"

module Poetry
  module Charts
    module Geometry
      # d3-array ticks / tickIncrement / tickStep against the d3 oracle.
      class TicksTest < ActiveSupport::TestCase
        include FixturesHelper

        def test_ticks_match_d3
          fixtures["ticks"].each do |kase|
            expected = kase["expected"]
            actual = Ticks.ticks(*kase["args"])

            assert_numbers_equal expected, actual, "ticks(#{kase["args"].join(", ")})"
          end
        end

        def test_tick_increment_matches_d3
          fixtures["tick_increment"].each do |kase|
            actual = Ticks.tick_increment(*kase["args"])
            if kase["expected"].nil?
              refute_predicate actual, :finite?, "tick_increment(#{kase["args"].join(", ")}) non-finite"
            else
              assert_equal kase["expected"], actual, "tick_increment(#{kase["args"].join(", ")})"
            end
          end
        end

        def test_tick_step_matches_d3
          fixtures["tick_step"].each do |kase|
            actual = Ticks.tick_step(*kase["args"])
            if kase["expected"].nil?
              refute_predicate actual, :finite?, "tick_step(#{kase["args"].join(", ")}) non-finite"
            else
              assert_equal kase["expected"], actual, "tick_step(#{kase["args"].join(", ")})"
            end
          end
        end
      end
    end
  end
end
