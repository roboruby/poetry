# frozen_string_literal: true

module Poetry
  module Ui
    module Combobox
      # Re-expressed through the cn-* theme layer. The embedded
      # Command parts still reuse Command::Style verbatim; the popup's
      # list and label are the combobox's own hooks. The input fills its
      # well (h-full, mechanics) rather than carrying the classic demo's
      # h-9 - every theme's well sizes it. The themed demo width still
      # loses to the width: knob (caller utilities beat the base layer).
      class Style < Poetry::Core::Style
        # The demo trigger IS Button's reference shape with the demo deltas
        # (justify-between, font-normal, the w-50 demo width) - all riding
        # .cn-combobox-trigger now.
        element :trigger, "cn-combobox-trigger inline-flex shrink-0 items-center justify-between " \
                          "whitespace-nowrap transition-all outline-none " \
                          "disabled:pointer-events-none disabled:opacity-50 " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        # The value DISPLAY truncates inside the fixed-width trigger.
        element :value, "truncate"
        # The width option's default - lives in the dictionary so the
        # safelist ships it and verify_compiled gates it (a bare Ruby
        # default string compiles in no host).
        element :default_width, "w-50"

        # The leading group (with_trigger only): a custom icon is a PREFIX
        # to the value, not a third justify-between child - grouped, the
        # chevrons stay the row's other end. min-w-0 keeps the value's
        # truncate working inside the flex group.
        element :trigger_leading, "flex min-w-0 items-center gap-2"

        # The popup: Popover's chrome retuned per the demo (p-0 - the
        # Command brings its own padding); the anchor-width binding stays
        # inline (popper measures the anchor and sets the generic var).
        # The column chain (flex-col + the popper's available-height cap,
        # the source's structural pair) lets the LIST shrink under
        # whatever cap the popup ends up with - the theme's design cap or
        # the viewport - instead of every theme subtracting the embedded
        # command's own padding; the list's themed max-height holds the
        # design height.
        element :content, "cn-combobox-content cn-menu-translucent z-50 flex w-(--anchor-width) " \
                          "max-h-(--available-height) origin-(--transform-origin) flex-col " \
                          "outline-hidden"

        # THE listbox, the popup's scroll owner: the source's combobox
        # list, where the option inset rides the LIST and groups stay
        # unpadded - an ungrouped option sits exactly where a grouped one
        # does, and the first row clears the search field in every theme.
        # (Command's list leaves the inset to its groups, the palette
        # convention; a combobox's options are usually ungrouped.)
        element :list, "cn-combobox-list overflow-x-hidden overflow-y-auto overscroll-contain"

        # A group: role=group around a label and its options. No hook and
        # no utilities ON PURPOSE - neither source styles the combobox
        # group (the label and the list carry the geometry); themes reach
        # it as [data-slot=command-group] inside the popup.
        element :group, ""

        # The group's label (the heading part): the source's combobox
        # label rule, themed per style.
        element :label, "cn-combobox-label"

        # The filter input fills its well: h-full is mechanics (the well's
        # height is the theme's - h-9 in default, the h-7/h-8 pill in the
        # ports), so the input keeps covering the whole field for pointer
        # focus without carrying a theme value. In default this lands where
        # the classic demo's h-9 retune did; the ports' source sizes the
        # input by its group the same way.
        element :input_fill, "h-full"

        # POETRY ADDITION (Command's precedent): the label wrapper is
        # layout-transparent - it mirrors the item's own row (preflight
        # blockifies svg, so a bare span would stack an icon above its text).
        element :item_text, "flex min-w-0 items-center gap-2"

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

        # The show_clear: X: a trigger SIBLING
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
