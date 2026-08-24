# frozen_string_literal: true

module Poetry
  module Ui
    # Semantic data tables composed from part helpers.
    module Table
      # A semantic <table> wrapped in a horizontally scrolling container.
      # Compose the sections with the part helpers (poetry_table_header /
      # _body / _row / _head / _cell / _footer / _caption), which render
      # real thead/tbody/tr/th/td elements carrying the family's styling.
      # Static and JS-free by itself - DataTable adds sorting, filtering,
      # and selection on top.
      #
      # sticky_header: true pins the <thead> while the container scrolls.
      # It only takes effect once container_class: caps the height (e.g.
      # "max-h-96"), and it requires scroll_label: - the container becomes
      # a focusable scroll region, which needs an accessible name.
      #
      # @example
      #   render Poetry::Ui::Table::Component.new do
      #     safe_join([
      #       poetry_table_header { poetry_table_row { poetry_table_head { "Invoice" } } },
      #       poetry_table_body { poetry_table_row { poetry_table_cell { "INV001" } } }
      #     ])
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Compose the table with the part helpers (poetry_table_header/_body/_row/_head/_cell) - " \
          "they carry the data-slot + classes onto real thead/tbody/tr/th/td.",
          "A column header is poetry_table_head (a <th>); a data cell is poetry_table_cell (a <td>).",
          "Mark a selected row with data-selected on poetry_table_row - never a bespoke highlight class.",
          "sticky_header: true pins the thead while the container scrolls - it only scrolls once " \
          "container_class: caps the height (\"max-h-96\"); without a cap nothing sticks.",
          "sticky_header requires scroll_label: - the container becomes a focusable scroll region " \
          "(tabindex=0 + role=region) and a keyboard-reachable region needs a name (the ScrollArea rule)."
        ].freeze

        # Pins the <thead> while the container scrolls; needs a height cap
        # (container_class:) to take effect, and requires scroll_label:.
        option :sticky_header, :boolean, default: false
        # Extra classes for the scroll container - e.g. "max-h-96" to cap its height.
        option :container_class, :string
        # The scroll region's accessible name, required with sticky_header:
        # a scrollable region a keyboard can't reach fails WCAG (axe
        # scrollable-region-focusable), and a focusable region needs a name.
        option :scroll_label, :string

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

        # No content = an empty <table> in a scroll container.
        requires_content "the table sections (poetry_table_* helpers)"

        # @api private
        def before_render
          ensure_content!
          return unless sticky_header && scroll_label.blank?

          raise ArgumentError,
                "Table sticky_header: requires scroll_label: (the scroll region's accessible name)"
        end

        # @api private
        def container_attributes
          extra = [(css(:container_sticky) if sticky_header), container_class].compact.join(" ")
          attrs = { "data-slot" => "table-container", "class" => css(:container, class: extra.presence) }
          attrs.merge!("tabindex" => "0", "role" => "region", "aria-label" => scroll_label) if sticky_header
          attrs
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "table" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
