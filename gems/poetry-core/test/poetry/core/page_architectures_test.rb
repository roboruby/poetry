# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The page-architecture catalog: the build_page plan step
    # renders every field of a matched archetype, so a missing key would
    # crash a live plan. These tests keep the seed data well-formed and the
    # scoring honest.
    class PageArchitecturesTest < Minitest::Test
      REQUIRED = %w[name title purpose keywords sections states edge_cases components].freeze
      NON_EMPTY = %w[keywords sections states edge_cases components].freeze
      # The eight vetted blocks a `block` reference may point at (or nil).
      BLOCKS = %w[action-bar app-shell data-index destructive-panel page-header
                  section-card stepper top-nav].freeze

      def test_every_archetype_is_well_formed
        PageArchitectures.all.each do |entry|
          REQUIRED.each do |key|
            assert entry.key?(key), "#{entry["name"].inspect} is missing #{key.inspect}"
          end
          NON_EMPTY.each do |list|
            refute_empty entry[list], "#{entry["name"].inspect} has an empty #{list}"
          end
          block = entry["block"]

          assert(block.nil? || BLOCKS.include?(block),
                 "#{entry["name"].inspect} references an unknown block: #{block.inspect}")
        end
      end

      def test_names_are_unique
        names = PageArchitectures.all.map { |entry| entry["name"] }

        assert_equal names.uniq, names, "archetype names must be unique"
      end

      def test_scoring_weights_keywords_over_prose_and_ranks_best_first
        # "dashboard" + "admin" are admin-dashboard keywords (2 each).
        scored = PageArchitectures.scored(Set["dashboard", "admin"])
        best, best_score = scored.first

        assert_equal "admin-dashboard", best["name"]
        assert_operator best_score, :>=, 4
      end

      def test_no_match_scores_zero
        scored = PageArchitectures.scored(Set["xyzzy", "plugh"])

        assert(scored.all? { |_entry, score| score.zero? })
      end
    end
  end
end
