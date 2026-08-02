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

        # The grid re-flow is structural and rides the dictionary like
        # upstream's cva (control auto-places into column 1, label pins to
        # column 2 row 1, hint/error stack under it - DOM stays label-first
        # for the for= association); the COLUMN GAP is design and lives
        # theme-side under the cn name. Vertical is the base state and
        # emits nothing (the marker/core-X empty-variant precedent).
        variant :orientation, {
          vertical: "",
          horizontal: "cn-field-orientation-horizontal grid-cols-[auto_1fr] items-center " \
                      "[&>[data-slot=label]]:col-start-2 [&>[data-slot=label]]:row-start-1 " \
                      "[&>[data-slot=field-hint]]:col-start-2 [&>[data-slot=field-error]]:col-start-2",
          # Horizontal mirrored and container-gated: stacked below the
          # FieldGroup's md mark; above it the label + hint pair stacks
          # tight in column 1 (the theme narrows the row gap to its
          # cn-field-content value via the marker class) and the control
          # spans both rows in column 2, centered against the whole pair
          # - upstream's FieldContent geometry, expressed on poetry's
          # flat quartet DOM. Outside a @container/field-group scope the
          # query never fires and the field stays vertical (upstream
          # parity: "container-aware parents").
          responsive: "cn-field-orientation-responsive " \
                      "@md/field-group:grid-cols-[1fr_auto] " \
                      "@md/field-group:[&>[data-slot=label]]:col-start-1 " \
                      "@md/field-group:[&>[data-slot=label]]:row-start-1 " \
                      "@md/field-group:[&>[data-slot=label]]:self-center " \
                      "@md/field-group:[&>[data-slot=field-hint]]:col-start-1 " \
                      "@md/field-group:[&>[data-slot=field-error]]:col-start-1 " \
                      "@md/field-group:[&>:not([data-slot=label],[data-slot=field-hint],[data-slot=field-error])]:col-start-2 " \
                      "@md/field-group:[&>:not([data-slot=label],[data-slot=field-hint],[data-slot=field-error])]:row-start-1 " \
                      "@md/field-group:[&>:not([data-slot=label],[data-slot=field-hint],[data-slot=field-error])]:row-span-2 " \
                      "@md/field-group:[&>:not([data-slot=label],[data-slot=field-hint],[data-slot=field-error])]:self-center"
        }

        element :hint, "cn-field-description"
        element :error, "cn-field-error"
      end
    end
  end
end
