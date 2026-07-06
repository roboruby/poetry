# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Table
      # The Table (N8): a real semantic <table> in an overflow container,
      # composed with the part helpers. Contract = the data-slot vocabulary
      # on real thead/tbody/tr/th/td + the selected-row hook. Part helpers
      # run through a real view flow (capture needs it); orphan table cells
      # are asserted on the raw string (HTML5 fragment parsing drops a <td>
      # outside a <table>).
      class ComponentTest < ViewComponent::TestCase
        def erb(source)
          ApplicationController.renderer.render(inline: source, layout: false)
        end

        def test_the_component_wraps_a_real_table_in_an_overflow_container
          fragment = render_inline(Component.new) { "rows" }
          container = fragment.css('[data-slot="table-container"]').first

          assert_includes container["class"], "overflow-x-auto"
          table = container.css('table[data-slot="table"]').first

          assert table, "a real <table> inside the container"
          assert_includes table["class"], "cn-table"
        end

        def test_the_part_helpers_stamp_data_slots_onto_semantic_elements
          # A full table context, so HTML5 parsing keeps the table elements.
          html = erb(<<~ERB)
            <%= poetry_table do %><%= poetry_table_header do %><%= poetry_table_row do %><%= poetry_table_head do %>H<% end %><% end %><% end %><% end %>
          ERB
          fragment = Nokogiri::HTML5.fragment(html)

          assert_predicate fragment.css('thead[data-slot="table-header"]'), :any?
          assert_predicate fragment.css('tr[data-slot="table-row"]'), :any?
          assert_equal "H", fragment.css('th[data-slot="table-head"]').first.text
        end

        def test_a_cell_is_a_td_and_takes_extra_attributes
          html = erb(%(<%= poetry_table_cell(colspan: 2, class: "text-right") { "Total" } %>))

          assert_match(/<td\b/, html)
          assert_includes html, 'colspan="2"'
          assert_includes html, "text-right"
          assert_includes html, "cn-table-cell" # the Style entry survives the extra class
          assert_includes html, 'data-slot="table-cell"'
        end

        def test_a_row_carries_the_selected_hook
          html = erb(%(<%= poetry_table_row(data: { selected: "" }) { "x" } %>))

          assert_includes html, "data-selected", "the Base UI selected vocabulary, not a bespoke class"
          assert_includes html, 'data-slot="table-row"'
        end

        def test_an_empty_cell_renders
          html = erb(%(<%= poetry_table_cell %>))

          assert_includes html, "<td" # no block = an empty cell, not a crash
          assert_includes html, 'data-slot="table-cell"'
        end
      end
    end
  end
end
