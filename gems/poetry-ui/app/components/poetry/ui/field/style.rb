# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      # Re-expressed through the cn-* theme layer. Poetry's Field is
      # its own small shape (grid + hint + error); the cn names borrow
      # upstream's vocabulary where semantics align (:hint wears
      # cn-field-description - the style hook tracks upstream naming, the
      # data-slot stays poetry's).
      class Style < Poetry::Core::Style
        base "cn-field grid group/field w-full"

        # The grid re-flow is structural and rides the dictionary like
        # upstream's cva (control auto-places into column 1, label pins to
        # column 2 row 1, hint/error stack under it - DOM stays label-first
        # for the for= association); the COLUMN GAP is design and lives
        # theme-side under the cn name. Vertical is the base state and
        # emits nothing (the marker/core-X empty-variant precedent).
        variant :orientation, {
          vertical: "",
          horizontal: "cn-field-orientation-horizontal grid-cols-[auto_1fr] items-center " \
                      "[&>[data-slot=field-label]]:col-start-2 [&>[data-slot=field-label]]:row-start-1 " \
                      "[&>[data-slot=field-description]]:col-start-2 [&>[data-slot=field-error]]:col-start-2",
          # The SETTING ROW (label + hint left, control right - upstream's
          # content-first horizontal Field): the horizontal treatment
          # mirrored, control auto-places beside the label line.
          setting: "cn-field-orientation-horizontal grid-cols-[1fr_auto] items-center " \
                   "[&>[data-slot=field-label]]:col-start-1 [&>[data-slot=field-label]]:row-start-1 " \
                   "[&>[data-slot=field-description]]:col-start-1 [&>[data-slot=field-error]]:col-start-1",
          # Horizontal mirrored and container-gated: stacked below the
          # FieldGroup's md mark; above it the label + hint pair stacks
          # tight in column 1 (the theme narrows the row gap to its
          # cn-field-content value via the marker class) and the control
          # spans both rows in column 2, centered against the whole pair
          # - upstream's FieldContent geometry, expressed on poetry's
          # flat quartet DOM. Outside a @container/field-group scope the
          # query never fires and the field stays vertical (upstream
          # parity: "container-aware parents").
          # rubocop:disable Layout/LineLength -- each line is one indivisible
          # utility token, and Tailwind scans this literal source (an
          # interpolated shared prefix would silently drop the CSS).
          responsive: "cn-field-orientation-responsive " \
                      "@md/field-group:grid-cols-[1fr_auto] " \
                      "@md/field-group:[&>[data-slot=field-label]]:col-start-1 " \
                      "@md/field-group:[&>[data-slot=field-label]]:row-start-1 " \
                      "@md/field-group:[&>[data-slot=field-label]]:self-center " \
                      "@md/field-group:[&>[data-slot=field-description]]:col-start-1 " \
                      "@md/field-group:[&>[data-slot=field-error]]:col-start-1 " \
                      "@md/field-group:[&>:not([data-slot=field-label],[data-slot=field-description],[data-slot=field-error])]:col-start-2 " \
                      "@md/field-group:[&>:not([data-slot=field-label],[data-slot=field-description],[data-slot=field-error])]:row-start-1 " \
                      "@md/field-group:[&>:not([data-slot=field-label],[data-slot=field-description],[data-slot=field-error])]:row-span-2 " \
                      "@md/field-group:[&>:not([data-slot=field-label],[data-slot=field-description],[data-slot=field-error])]:self-center"
          # rubocop:enable Layout/LineLength
        }

        # The Label wears the source's field-label slot and its structural
        # tokens on top of its own (a composed Label, the outer's part).
        element :label, "cn-field-label group/field-label peer/field-label flex w-fit items-center " \
                        "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col"
        element :hint, "cn-field-description [&>a:hover]:text-primary [&>a]:underline " \
                       "[&>a]:underline-offset-4 font-normal group-has-data-horizontal/field:text-balance " \
                       "last:mt-0 leading-normal nth-last-2:-mt-1"
        element :error, "cn-field-error font-normal"
      end
    end
  end
end
