# frozen_string_literal: true

module Poetry
  module Ui
    module Select
      # Style dictionary for the Select family.
      class Style < Poetry::Core::Style
        element :trigger, "cn-select-trigger flex w-fit items-center justify-between whitespace-nowrap " \
                          "outline-none disabled:cursor-not-allowed disabled:opacity-50 " \
                          "*:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex " \
                          "*:data-[slot=select-value]:items-center " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :content, "cn-select-content cn-menu-translucent relative z-50 max-h-(--available-height) " \
                          "origin-(--transform-origin) overflow-x-hidden overflow-y-auto " \
                          "isolate w-(--anchor-width)"

        # Padding/scroll-margin are theme-owned via cn-select-viewport
        # (sera runs p-1.5). Sizing vars stay structural.
        # min-h on purpose, never a hard h: a hard h collapses the whole
        # popup to trigger height (62px for a five-item list) the moment
        # the trigger-height var is fed (goldens never see open popups, so
        # only a human catches it).
        element :viewport, "cn-select-viewport min-h-[var(--radix-select-trigger-height)] w-full " \
                           "min-w-[var(--radix-select-trigger-width)]"

        element :item, "cn-select-item relative flex w-full cursor-default items-center outline-hidden " \
                       "select-none [&_svg]:pointer-events-none [&_svg]:shrink-0 data-disabled:opacity-50 " \
                       "data-disabled:pointer-events-none"

        element :label, "cn-select-label"

        element :separator, "cn-select-separator pointer-events-none"

        element :scroll_button, ""

        # The indicator wrapper span - the RIGHT-2 gutter, the mirror image
        # of dropdown-menu's left gutter.
        element :item_indicator, "cn-select-item-indicator absolute flex items-center justify-center"

        # The check stays in the DOM always; the parent item's bare
        # data-selected drives visibility (unselected = attribute ABSENCE -
        # no data-unselected exists), so the controller's
        # aria-selected/data-selected twin-flip is the whole toggle.
        element :item_indicator_state, "[:not([data-selected])>&]:hidden"

        # The form bubble: visually hidden but PAINTED (sr-only clips, never
        # display:none - browser autofill heuristics skip unpainted controls).
        element :native, "sr-only"

        # The source's inline lucide icon classes, named per part.
        element :trigger_icon, "cn-select-trigger-icon"
        element :indicator_check, "size-4"
        element :scroll_icon, ""
      end
    end
  end
end
