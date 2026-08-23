# frozen_string_literal: true

module Poetry
  module Ui
    module DropdownMenu
      # Re-expressed through the cn-* theme layer: panel/item chrome,
      # focus treatments, and the animate chains ride themes/default.css;
      # popper vars, overflow, and the poetry indicator-visibility switch
      # stay inline. Icon glyph classes stay inline per upstream (TSX
      # inlines them on the lucide elements).
      class Style < Poetry::Core::Style
        element :content, "cn-dropdown-menu-content cn-menu-translucent z-50 " \
                          "max-h-(--available-height) " \
                          "origin-(--transform-origin) " \
                          "overflow-x-hidden overflow-y-auto"

        # group/dropdown-menu-item: bare marker, no CSS - the vega
        # shortcut re-color (group-focus/dropdown-menu-item) keys on it.
        element :item, "cn-dropdown-menu-item group/dropdown-menu-item relative flex cursor-default " \
                       "items-center outline-hidden select-none data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :checkbox_item, "cn-dropdown-menu-checkbox-item relative flex cursor-default " \
                                "items-center outline-hidden select-none " \
                                "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                                "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :radio_item, "cn-dropdown-menu-radio-item relative flex cursor-default items-center " \
                             "outline-hidden select-none data-[disabled]:pointer-events-none " \
                             "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :label, "cn-dropdown-menu-label"

        element :separator, "cn-dropdown-menu-separator"

        element :shortcut, "cn-dropdown-menu-shortcut"

        element :sub_trigger, "cn-dropdown-menu-sub-trigger flex cursor-default items-center " \
                              "outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :sub_content, "cn-dropdown-menu-sub-content z-50 " \
                              "origin-(--transform-origin) overflow-hidden"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it dropdown-menu-item-indicator - the self-identification rule).
        element :item_indicator, "cn-dropdown-menu-item-indicator pointer-events-none absolute " \
                                 "flex items-center justify-center"

        # POETRY ADDITION: the source renders the indicator only while
        # checked (Radix ItemIndicator unmounts); poetry keeps it in the
        # DOM and the parent item's data-checked/data-unchecked pair drives
        # visibility, so the controller's aria-checked/data-checked flip is
        # the whole toggle.
        element :item_indicator_state, "[[data-unchecked]>&]:hidden"

        # The source's inline lucide icon classes, named per part.
        element :indicator_check, "size-4"
        element :indicator_circle, "size-2 fill-current"
        element :sub_indicator, "ml-auto size-4"
      end
    end
  end
end
