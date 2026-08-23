# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # Re-expressed through the cn-* theme layer: the chrome rides
      # poetry-named rules (own component - no upstream cn vocabulary).
      class Style < Poetry::Core::Style
        base "w-full"

        element :toolbar, "cn-data-table-toolbar flex items-center"
        element :container, "cn-data-table-container overflow-hidden " \
                            "[&_tr[data-selected]]:bg-muted/50"
        element :footer, "cn-data-table-footer"
        element :empty, "cn-data-table-empty"

        # POETRY ADDITION: the caption lives INSIDE the bordered container
        # (a <caption> cannot leave its <table>), so Table's mt-4 needs a
        # matching bottom margin or the text hugs the frame's border.
        # Upstream never composes this - its bordered data-table demo has
        # no caption; its captioned table demo has no border.
        element :caption, "mb-4"

        # POETRY ADDITION: the ghost sort button's px-3 shifts the header
        # LABEL 12px off the column's data text (upstream's demo carries
        # the same quirk and users patch it with a negative margin - here
        # the component owns the link, so the component compensates).
        # Negative on BOTH sides: only the binding side of the cell's
        # text-align has any layout effect, so one class serves left- and
        # right-aligned columns alike.
        element :sort_link, "-mx-3"
        # Selection: native checkboxes on the token accent; the
        # selected-row wash rides the container (rows are controller-
        # marked data-selected).
        element :checkbox, "size-4 shrink-0 translate-y-px rounded-sm border-input " \
                           "accent-primary outline-none " \
                           "focus-visible:ring-[3px] focus-visible:ring-ring/50"
        element :select_cell, "w-10"
      end
    end
  end
end
