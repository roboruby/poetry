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

        # The leading group (with_trigger only): a custom icon is a PREFIX
        # to the value, not a third justify-between child - grouped, the
        # chevrons stay the row's other end. min-w-0 keeps the value's
        # truncate working inside the flex group.
        element :trigger_leading, "flex min-w-0 items-center gap-2"

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

        # The chips FIELD frame (multiple: - replaces the trigger): the
        # flex-wrap mechanism stays inline; the input-frame chrome (border,
        # ring, paddings, min-height, the chips-present padding tighten)
        # rides themes/*.css. The disabled plumbing mirrors the trigger's.
        element :chips, "cn-combobox-chips flex flex-wrap items-center " \
                        "data-disabled:pointer-events-none data-disabled:opacity-50"

        # One chip: real-focus surface (:focus-visible ring is theme-side).
        element :chip, "cn-combobox-chip flex shrink-0 items-center outline-none"

        # ChipRemove: the ghost icon-button mechanism; the dim/hover/size
        # treatment is theme-side.
        element :chip_remove, "cn-combobox-chip-remove inline-flex shrink-0 items-center " \
                              "justify-center outline-none [&_svg]:pointer-events-none [&_svg]:shrink-0"

        # The inline filter input: bare (the FRAME is the visual field) -
        # min-width and placeholder color are theme-side.
        element :chip_input, "cn-combobox-chip-input flex-1 bg-transparent outline-none"

        # The show_clear: positioning wrapper - shrink-wraps the trigger so
        # the absolute X seats against the TRIGGER's edge, not the
        # full-width root (the root is a block; end-2 against it lands at
        # the page edge). Rendered ONLY when show_clear - every other
        # instance keeps its wrapper-free markup.
        element :clear_anchor, "relative inline-flex"

        # The show_clear: X (Base UI Combobox.Clear): a trigger SIBLING
        # (button-in-button is invalid) absolutely seated over the chevron
        # slot (px-3 gutter + size-4 icon -> a size-6 hitbox at end-2
        # centers on it). Structural-only chrome, like the chevron itself.
        element :clear, "absolute end-2 top-1/2 flex size-6 -translate-y-1/2 items-center " \
                        "justify-center rounded-sm opacity-50 outline-none transition-opacity " \
                        "hover:opacity-100 focus-visible:opacity-100 focus-visible:ring-[3px] " \
                        "focus-visible:ring-ring/50 disabled:pointer-events-none"
        element :clear_icon, "size-4"

        # The chevron half of the clear swap: while the sibling X is
        # showable (not [hidden]), the chevron goes INVISIBLE - visibility,
        # never display, so it keeps its flex box and the value text never
        # slides under the absolute X (the item_indicator_state pattern).
        element :trigger_icon_swap,
                "[[data-slot=combobox-trigger]:has(+[data-slot=combobox-clear]:not([hidden]))_&]:invisible"

        # The source's inline lucide icon classes, named per part. The
        # double chevron is the combobox tell (Select wears chevron-down).
        element :trigger_icon, "size-4 opacity-50"
        element :indicator_check, "size-4"
        element :chip_remove_icon, "size-3"
      end
    end
  end
end
