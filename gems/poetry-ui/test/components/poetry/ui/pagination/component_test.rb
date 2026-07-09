# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Pagination
      # The Pagination (N8): data-driven, so the contract is the truncation
      # math + the accessible nav (aria-current, aria-label, disabled edges).
      class ComponentTest < ViewComponent::TestCase
        PATH = ->(page) { "?page=#{page}" }

        def render_pagination(current:, total:, **)
          render_inline(Component.new(current: current, total: total, path: PATH, **))
        end

        # --- the truncation math ---

        def test_a_short_range_shows_every_page
          assert_equal [1, 2, 3, 4], Component.new(current: 2, total: 4, path: PATH).items
        end

        def test_a_long_range_windows_around_current_with_gaps
          assert_equal [1, :gap, 4, 5, 6, :gap, 20],
                       Component.new(current: 5, total: 20, path: PATH).items
        end

        def test_the_window_widens_with_siblings
          assert_equal [1, :gap, 3, 4, 5, 6, 7, :gap, 20],
                       Component.new(current: 5, total: 20, siblings: 2, path: PATH).items
        end

        def test_near_an_edge_only_one_gap_appears
          assert_equal [1, 2, 3, :gap, 20], Component.new(current: 2, total: 20, path: PATH).items
        end

        # --- the accessible nav ---

        def test_it_is_a_labelled_navigation_landmark
          nav = render_pagination(current: 4, total: 10).css('nav[data-slot="pagination"]').first

          assert_equal "navigation", nav["role"]
          assert_equal "pagination", nav["aria-label"]
        end

        def test_the_current_page_is_marked_and_styled
          fragment = render_pagination(current: 4, total: 10)
          current = fragment.css('[aria-current="page"]').first

          assert current, "the current page carries aria-current"
          assert_equal "true", current["data-active"]
          assert_equal "outline", current["data-variant"], "current = outline; the rest are ghost"
        end

        # Blocks v1.1: the opt-in filled treatment - primary Button
        # as the unambiguous active state; parity default untouched above.
        def test_the_filled_current_variant_renders_the_primary_button
          fragment = render_pagination(current: 4, total: 10, current_variant: :filled)
          current = fragment.css('[aria-current="page"]').first

          assert_equal "default", current["data-variant"], "filled = the primary Button treatment"
          other = fragment.css('a[data-slot="pagination-link"]:not([aria-current])').first

          assert_equal "ghost", other["data-variant"], "non-current pages stay ghost under :filled"
        end

        def test_the_current_variant_enum_is_registry_visible
          # The inclusion validator projects into the registry (Blocks
          # v1.1), so poetry check rejects current_variant: :solid
          # statically - the roster's enum options are contracts, not
          # documentation.
          entry = Component.prop_definitions[:options].find { |option| option[:name] == :current_variant }

          assert_equal %i[outline filled], entry[:variants]
        end

        def test_page_links_are_real_anchors_with_the_path
          links = render_pagination(current: 4, total: 10).css('a[data-slot="pagination-link"]')

          assert(links.any? { |a| a["href"] == "?page=5" }, "the path: callable builds each href")
        end

        def test_previous_is_disabled_on_the_first_page
          fragment = render_pagination(current: 1, total: 10)
          previous = fragment.css('[aria-label="Go to previous page"]').first

          assert_equal "true", previous["aria-disabled"], "no previous page to go to"
        end

        def test_next_is_disabled_on_the_last_page
          fragment = render_pagination(current: 10, total: 10)
          nxt = fragment.css('[aria-label="Go to next page"]').first

          assert_equal "true", nxt["aria-disabled"]
        end

        def test_the_ellipsis_is_decorative_with_sr_text
          ellipsis = render_pagination(current: 10, total: 20).css('[data-slot="pagination-ellipsis"]').first

          assert_equal "true", ellipsis["aria-hidden"]
          assert_includes ellipsis.text, "More pages"
        end
      end
    end
  end
end
