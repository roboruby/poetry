# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module DataTable
      # The URL-state sanitizer: order_clause must be injection-safe BY
      # CONSTRUCTION, so hostile params are the main corpus here.
      class StateTest < ActiveSupport::TestCase
        def build(params = {}, sortable: %w[title created_at], **)
          State.from_params(params, sortable: sortable, **)
        end

        def test_a_whitelisted_sort_survives_with_its_direction
          state = build({ sort: "title", dir: "desc" })

          assert_equal({ "title" => :desc }, state.order_clause)
        end

        def test_an_injection_attempt_never_reaches_order
          state = build({ sort: "title; DROP TABLE notes;--", dir: "asc" })

          assert_nil state.order_clause, "an unlisted sort column falls back to no ordering"
        end

        def test_a_garbage_direction_falls_back_to_the_default
          state = build({ sort: "title", dir: "ASC) UNION SELECT" })

          assert_equal({ "title" => :asc }, state.order_clause)
        end

        def test_defaults_apply_when_params_are_absent
          state = build({}, default_sort: "created_at", default_dir: "desc")

          assert_equal({ "created_at" => :desc }, state.order_clause)
        end

        def test_page_is_clamped_to_a_positive_integer
          assert_equal 1, build({ page: "0" }).page
          assert_equal 1, build({ page: "-3" }).page
          assert_equal 1, build({ page: "garbage" }).page
          assert_equal 7, build({ page: "7" }).page
        end

        def test_a_blank_query_is_nil
          assert_nil build({ q: "   " }).q
          assert_equal "acme", build({ q: " acme " }).q
        end

        def test_toggle_flips_the_active_column_and_resets_the_page
          state = build({ sort: "title", dir: "asc", q: "x", page: "3" })
          params = state.toggle_params("title")

          assert_equal({ q: "x", sort: "title", dir: "desc" }, params)
          assert_nil params[:page], "a new ordering is a new list"
        end

        def test_toggle_starts_a_new_column_ascending
          state = build({ sort: "title", dir: "desc" })

          assert_equal({ sort: "created_at", dir: "asc" }, state.toggle_params("created_at"))
        end

        def test_page_params_keep_the_view_and_omit_page_one
          state = build({ sort: "title", dir: "asc", q: "x" })

          assert_equal({ q: "x", sort: "title", dir: "asc", page: 2 }, state.page_params(2))
          assert_nil state.page_params(1)[:page]
        end

        def test_filter_params_carry_sort_but_reset_query_and_page
          state = build({ sort: "title", dir: "asc", q: "x", page: "3" })

          assert_equal({ sort: "title", dir: "asc" }, state.filter_params)
        end

        def test_page_one_and_blank_pieces_stay_out_of_urls
          assert_empty build({}, default_sort: nil).to_params
        end
      end
    end
  end
end
