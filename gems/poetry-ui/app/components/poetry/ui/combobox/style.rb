# frozen_string_literal: true

module Poetry
  module Ui
    module Combobox
      # Re-expressed through the cn-* theme layer (N11). The embedded
      # Command parts still reuse Command::Style verbatim. The demo's
      # h-9 input retune stays INLINE (a utilities-layer override that
      # beats the themed cn-command-input h-10 - the cn() behavior). The
      # themed demo width still loses to the width: knob (caller
      # utilities beat the base layer).
      class Style < Poetry::Core::Style
        # The demo trigger IS the golden Button shape with the demo deltas
        # (justify-between, font-normal, the w-50 demo width) - all riding
        # .cn-combobox-trigger now.
        element :trigger, "cn-combobox-trigger inline-flex shrink-0 items-center justify-between " \
                          "whitespace-nowrap transition-all outline-none " \
                          "disabled:pointer-events-none disabled:opacity-50 " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        # The value DISPLAY truncates inside the fixed-width trigger.
        element :value, "truncate"

        # The popup: Popover's chrome retuned per the demo (p-0 - the
        # Command brings its own padding); the anchor-width binding stays
        # inline (popper measures the anchor and sets the generic var).
        element :content, "cn-combobox-content z-50 w-(--anchor-width) origin-(--transform-origin) " \
                          "outline-hidden"

        # The demo's CommandInput className="h-9" retune, merged over
        # Command's own :input (beats the themed h-10 from the utilities
        # layer, exactly as the class merger used to).
        element :input_scale, "h-9"

        # The committed-value check: TRAILING ms-auto per the demo (not
        # Select's absolute right-2 gutter) - the family RTL fix.
        element :item_indicator, "cn-combobox-item-indicator ms-auto flex items-center justify-center"

        # POETRY ADDITION (Select's precedent): server-rendered always; the
        # parent item's bare data-selected drives visibility.
        element :item_indicator_state, "[:not([data-selected])>&]:hidden"

        # The form bubble: visually hidden but PAINTED (sr-only clips,
        # never display:none - autofill heuristics skip unpainted controls).
        element :native, "sr-only"

        # The source's inline lucide icon classes, named per part. The
        # double chevron is the combobox tell (Select wears chevron-down).
        element :trigger_icon, "size-4 opacity-50"
        element :indicator_check, "size-4"
      end
    end
  end
end
