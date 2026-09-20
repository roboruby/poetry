# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/parallel"

module Poetry
  module Eval
    class ParallelTest < Minitest::Test
      def test_every_unit_runs_once_and_the_lock_serializes_the_records
        seen = []
        Parallel.each((1..20).to_a, concurrency: 4) do |unit, lock|
          lock.synchronize { seen << unit }
        end

        assert_equal (1..20).to_a, seen.sort
      end

      def test_no_units_means_no_workers_and_an_empty_list_is_fine
        Parallel.each([], concurrency: 4) { |_unit, _lock| flunk "nothing to run" }
      end

      def test_a_worker_failure_propagates_from_the_join
        assert_raises(RuntimeError) do
          Parallel.each([1, 2], concurrency: 2) { |unit, _lock| raise "unit #{unit}" if unit == 2 }
        end
      end
    end
  end
end
