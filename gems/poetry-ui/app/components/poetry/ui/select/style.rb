# frozen_string_literal: true

module Poetry
  module Ui
    module Select
      # Re-expressed through the cn-* theme layer (N11). Still popper-only
      # (the source's popper-conditional classes stay baked in - now inside
      # the theme rules). Mechanisms inline: popper vars, the viewport's
      # trigger-size binding (whole part machinery, unnamed), the
      # indicator-visibility switch, the sr-only form bubble, glyph sizes.
      class Style < Poetry::Core::Style
        element :trigger, "cn-select-trigger flex w-fit items-center justify-between whitespace-nowrap " \
                          "outline-none disabled:cursor-not-allowed disabled:opacity-50 " \
                          "*:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex " \
                          "*:data-[slot=select-value]:items-center " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :content, "cn-select-content relative z-50 " \
                          "max-h-(--available-height) " \
                          "origin-(--transform-origin) " \
                          "overflow-x-hidden overflow-y-auto"

        # Padding/scroll-margin are theme-owned via cn-select-viewport
        # (W5 roster pass; sera runs p-1.5). Sizing vars stay structural.
        element :viewport, "cn-select-viewport h-[var(--radix-select-trigger-height)] w-full " \
                           "min-w-[var(--radix-select-trigger-width)]"

        element :item, "cn-select-item relative flex w-full cursor-default items-center " \
                       "outline-hidden select-none data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                       "*:[span]:last:flex *:[span]:last:items-center"

        element :label, "cn-select-label"

        element :separator, "cn-select-separator pointer-events-none"

        element :scroll_button, "flex cursor-default items-center justify-center py-1"

        # Source-exact wrapper span (named select-item-indicator in
        # new-york-v4) - the RIGHT-2 gutter, the mirror image of
        # dropdown-menu's left gutter.
        element :item_indicator, "cn-select-item-indicator absolute flex items-center justify-center"

        # POETRY ADDITION: the source renders the check only while selected
        # (Radix ItemIndicator unmounts); poetry keeps it in the DOM and the
        # parent item's bare data-selected drives visibility (unselected =
        # attribute ABSENCE - no data-unselected exists), so the controller's
        # aria-selected/data-selected twin-flip is the whole toggle.
        element :item_indicator_state, "[:not([data-selected])>&]:hidden"

        # The form bubble: visually hidden but PAINTED (sr-only clips, never
        # display:none - browser autofill heuristics skip unpainted controls).
        element :native, "sr-only"

        # The source's inline lucide icon classes, named per part.
        element :trigger_icon, "cn-select-trigger-icon"
        element :indicator_check, "size-4"
        element :scroll_icon, "size-4"
      end
    end
  end
end
