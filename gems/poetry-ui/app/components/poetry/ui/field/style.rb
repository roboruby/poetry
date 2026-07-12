# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      # Re-expressed through the cn-* theme layer (N11). Poetry's Field is
      # its own small shape (grid + hint + error); the cn names borrow
      # upstream's vocabulary where semantics align (:hint wears
      # cn-field-description - the style hook tracks upstream naming, the
      # data-slot stays poetry's).
      class Style < Poetry::Core::Style
        base "cn-field grid"

        # The layout is structural, so it rides the dictionary exactly like
        # upstream's cva (fieldVariants carries these as utilities, not
        # theme design). Horizontal: control auto-places into the first
        # column, label pins to column 2 row 1, hint/error stack under it -
        # DOM order stays label-first (the for= association), the grid
        # reorders visually.
        variant :orientation, {
          vertical: "cn-field-orientation-vertical",
          horizontal: "cn-field-orientation-horizontal grid-cols-[auto_1fr] items-center gap-x-3 " \
                      "[&>[data-slot=label]]:col-start-2 [&>[data-slot=label]]:row-start-1 " \
                      "[&>[data-slot=field-hint]]:col-start-2 [&>[data-slot=field-error]]:col-start-2"
        }

        element :hint, "cn-field-description"
        element :error, "cn-field-error"
      end
    end
  end
end
