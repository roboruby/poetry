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
          "Mark a selected row with data-selected on poetry_table_row - never a bespoke highlight class.",
          "sticky_header: true pins the thead while the container scrolls - it only scrolls once " \
          "container_class: caps the height (\"max-h-96\"); without a cap nothing sticks."
        ].freeze

        option :sticky_header, :boolean, default: false
        option :container_class, :string

        part "table", "The semantic <table> element itself - the root the part helpers compose into"
        part "table-caption", "The <caption> (poetry_table_caption) - the table's accessible purpose"
        part "table-header", "The <thead> (poetry_table_header) holding the column-header row"
        part "table-body", "The <tbody> (poetry_table_body) holding the data rows"
        part "table-footer", "The <tfoot> (poetry_table_footer) - totals/summary rows"
        part "table-row", "A <tr> (poetry_table_row) in any section",
             states: {
               "data-selected" => "the row is marked selected (presence attribute, no value) - " \
                                  "the theme tints it"
             }
        part "table-head", "A column header <th> (poetry_table_head)"
        part "table-cell", "A data <td> (poetry_table_cell)"

        def container_attributes
          extra = [(css(:container_sticky) if sticky_header), container_class].compact.join(" ")
          { "data-slot" => "table-container", "class" => css(:container, class: extra.presence) }
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
