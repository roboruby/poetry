# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class MergerTest < Minitest::Test
        def setup
          @merger = Merger.new
        end

        def test_merges_and_resolves_tailwind_conflicts
          assert_equal "p-4 text-blue-500", @merger.merge("text-red-500 p-4", "text-blue-500")
        end

        def test_returns_nil_for_blank_input
          assert_nil @merger.merge(nil, "", [])
        end

        def test_repeat_merges_hit_the_cache
          first = @merger.merge("p-4", "rounded")
          second = @merger.merge("p-4", "rounded")

          assert_same first, second, "identical input must return the cached (same) result object"
        end

        def test_cache_is_bounded_fifo
          limit = Merger::CACHE_LIMIT
          (limit + 10).times { |i| @merger.merge("p-#{i}") }
          cache = @merger.instance_variable_get(:@cache)

          assert_operator cache.size, :<=, limit
          refute cache.key?("p-0"), "oldest entries must be evicted first"
          assert cache.key?("p-#{limit + 9}")
        end
      end
    end
  end
end
