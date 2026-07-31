# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module DataTable
      class ComponentTest < ViewComponent::TestCase
        Row = Struct.new(:title, :author, keyword_init: true)

        ROWS = [
          Row.new(title: "Beta", author: "Ada"),
          Row.new(title: "Alpha", author: "Grace")
        ].freeze

        def state(params = {}, sortable: %w[title author], **)
          State.from_params(params, sortable: sortable, **)
        end

        def path
          ->(params) { "/notes?#{params.to_query}" }
        end

        def render_table(rows: ROWS, table_state: state({ sort: "title", dir: "asc" }), **, &block)
          block ||= lambda { |t|
            t.with_column("Title", key: :title, sortable: true, &:title)
            t.with_column("Author", &:author)
          }
          render_inline(Component.new(rows: rows, state: table_state, path: path, **), &block)
        end

        def test_renders_a_real_table_with_column_headers_and_cells
          html = render_table(caption: "Recent notes")

          assert_equal "Recent notes", html.css("caption").text.strip
          # The caption sits INSIDE the bordered container: Table's mt-4
          # plus the data-table's own mb-4, or it hugs the frame's border.
          assert_includes html.css("caption").first["class"].split, "mb-4"
          assert_equal(%w[Title Author], html.css("th").map { |th| th.text.strip })
          assert_equal(%w[Beta Ada], html.css("tbody tr").first.css("td").map { |td| td.text.strip })
        end

        def test_sticky_header_forwards_to_the_inner_table_container
          html = render_table(sticky_header: true, container_class: "max-h-56", caption: "Recent notes")
          container = html.css('[data-slot="table-container"]').first

          assert_includes container["class"], "[&_thead]:sticky"
          assert_includes container["class"], "max-h-56"
          assert_equal "Recent notes", container["aria-label"], "scroll_label falls back to the caption"
          assert_equal "0", container["tabindex"]
        end

        def test_the_active_column_announces_its_sort
          html = render_table

          assert_equal "ascending", html.css("th[aria-sort]").first["aria-sort"]
          assert_equal 1, html.css("th[aria-sort]").length, "only the active column carries aria-sort (APG)"
        end

        def test_sort_headers_are_real_links_to_the_toggled_ordering
          html = render_table

          link = html.css('[data-slot="data-table-sort"]').first

          assert_equal "a", link.name, "keyboard, middle-click, and share all need a real href"
          assert_includes link["href"], "sort=title"
          assert_includes link["href"], "dir=desc", "clicking the active asc column toggles to desc"
          # The ghost padding compensation: label text sits ON the column's
          # data text, not 12px off it.
          assert_includes link["class"].split, "-mx-3"
        end

        def test_the_filter_form_is_a_labelled_get_search_carrying_the_sort
          html = render_table(table_state: state({ sort: "title", dir: "asc", q: "beta", page: "3" }))

          form = html.css('form[data-slot="data-table-filter"]').first

          assert_equal "get", form["method"]
          assert_equal "search", form["role"]
          input = form.css("input[name=q]").first

          assert_equal "beta", input["value"]
          assert_equal form.css("label").first["for"], input["id"], "the filter input is labelled"
          assert_equal "title", form.css("input[type=hidden][name=sort]").first["value"]
          assert_empty form.css("input[type=hidden][name=page]"), "a new filter resets the page"
        end

        def test_pagination_renders_only_with_multiple_pages_and_keeps_the_view
          html = render_table(total: 3, table_state: state({ sort: "title", dir: "asc", q: "x" }))

          nav = html.css('nav[data-slot="pagination"]').first

          assert nav, "total: > 1 renders Pagination"
          page_two = nav.css("a").find { |a| a.text.strip == "2" }

          assert_includes page_two["href"], "page=2"
          assert_includes page_two["href"], "q=x", "pagination preserves the filtered view"

          assert_empty render_table(total: 1).css('[data-slot="pagination"]')
        end

        def test_no_rows_renders_the_empty_cell_across_all_columns
          html = render_table(rows: [])

          cell = html.css("tbody td").first

          assert_equal "2", cell["colspan"]
          assert_equal "No results.", cell.text.strip
        end

        def test_a_frame_wraps_the_table_and_advances_the_url
          html = render_table(frame: "notes-table")

          frame = html.css("turbo-frame").first

          assert_equal "notes-table", frame["id"]
          assert_equal "advance", frame["data-turbo-action"]
          assert_predicate frame.css("table"), :any?
        end

        def test_a_sortable_column_missing_from_the_whitelist_raises_at_render
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(rows: ROWS, state: state({}, sortable: %w[title]), path: path)) do |t|
              t.with_column("Author", key: :author, sortable: true, &:author)
            end
          end

          assert_match(/missing from the controller's State sortable: whitelist/, error.message)
        end

        def test_a_table_without_columns_raises
          assert_raises(ArgumentError) do
            render_inline(Component.new(rows: ROWS, state: state, path: path))
          end
        end
      end
    end
  end
end
