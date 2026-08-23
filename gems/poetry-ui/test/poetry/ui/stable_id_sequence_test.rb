# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The opt-in StableId sequence mode, end to end: the
    # engine-installed around_action seeds a per-request deterministic id
    # sequence when stable_id_mode == :sequence, and does nothing
    # otherwise. The proof rides the gate page: /sgate?keyed=0 renders
    # UNKEYED dropdowns per row, so its body is byte-stable exactly when
    # the sequence is armed.
    class StableIdSequenceTest < ActionDispatch::IntegrationTest
      def test_sequence_mode_makes_unkeyed_pages_byte_identical
        with_mode(:sequence) do
          assert_equal sgate_body, sgate_body,
                       "same path + sequence mode must replay identical ids"
        end
      end

      def test_off_mode_keeps_unkeyed_pages_random
        with_mode(:off) do
          refute_equal sgate_body, sgate_body,
                       "without the mode, unkeyed ids must stay random per render"
        end
      end

      def test_same_path_draws_the_same_id_set_regardless_of_query
        with_mode(:sequence) do
          get "/sgate?keyed=0&order=asc"
          first = response.body
          # Same PATH, different query: Turbo treats these as the same
          # page for refresh purposes, and so does the seed.
          get "/sgate?keyed=0&order=desc"

          assert_equal first.scan(/poetry-dropdown-menu-\h{16}/).uniq.sort,
                       response.body.scan(/poetry-dropdown-menu-\h{16}/).uniq.sort,
                       "same path must draw the same id set regardless of query"
        end
      end

      private

      def with_mode(mode)
        config = Poetry::Core::Config.current
        previous = config.stable_id_mode
        config.stable_id_mode = mode
        yield
      ensure
        config.stable_id_mode = previous
      end

      def sgate_body
        get "/sgate?keyed=0&order=asc"

        assert_response :success
        response.body
      end
    end
  end
end
