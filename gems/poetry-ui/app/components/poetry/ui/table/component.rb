# frozen_string_literal: true

module Poetry
  module Ui
    module Table
      # The Table - a real semantic `<table>` wrapped in an overflow
      # container. Composed with the part helpers (poetry_table_header /
      # _body / _row / _head / _cell / _footer / _caption), which stamp the
      # data-slot + source-exact classes onto the semantic elements. Zero JS;
      # DataTable (N8 W3) drives sorting/filtering/selection on top.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Compose the table with the part helpers (poetry_table_header/_body/_row/_head/_cell) - " \
          "they carry the data-slot + classes onto real thead/tbody/tr/th/td.",
          "A column header is poetry_table_head (a <th>); a data cell is poetry_table_cell (a <td>).",
          "Mark a selected row with data-selected on poetry_table_row - never a bespoke highlight class."
        ].freeze

        def container_attributes
          { "data-slot" => "table-container", "class" => css(:container) }
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "table" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
