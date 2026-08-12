# frozen_string_literal: true

module Poetry
  module Ui
    module Checkbox
      # Re-expressed through the cn-* theme layer (N11): the well treatment
      # rides .cn-checkbox in themes/default.css. Poetry mechanisms stay
      # inline: data-unchecked:invisible keeps the indicator in the DOM
      # CSS-hidden (Radix unmounts via Presence; there is no exit animation
      # to await), the glyph size matches source (CheckIcon size-3.5,
      # upstream-inline in TSX), and :input is the sr-only form store.
      class Style < Poetry::Core::Style
        base "cn-checkbox peer relative shrink-0 outline-none after:absolute " \
             "after:-inset-x-3 after:-inset-y-2 " \
             "disabled:cursor-not-allowed disabled:opacity-50"

        element :indicator, "cn-checkbox-indicator grid place-content-center text-current transition-none " \
                            "data-unchecked:invisible"

        element :icon, ""

        # The form participant + the store: visually hidden, out of the
        # accessibility tree (the button is the accessible control).
        element :input, "sr-only"
      end
    end
  end
end
