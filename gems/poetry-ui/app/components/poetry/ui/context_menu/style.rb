# frozen_string_literal: true

module Poetry
  module Ui
    module ContextMenu
      # Re-expressed through the cn-* theme layer (N11). The family deltas
      # vs DropdownMenu now read off the theme rules (context-menu label
      # adds text-foreground, the sub-trigger omits gap-2, the sub chevron
      # is a bare ml-auto); the trigger SURFACE still ships no classes.
      class Style < Poetry::Core::Style
        element :content, "cn-context-menu-content z-50 " \
                          "max-h-(--radix-context-menu-content-available-height) " \
                          "origin-(--radix-context-menu-content-transform-origin) " \
                          "overflow-x-hidden overflow-y-auto"

        element :item, "cn-context-menu-item relative flex cursor-default items-center " \
                       "outline-hidden select-none data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :checkbox_item, "cn-context-menu-checkbox-item relative flex cursor-default " \
                                "items-center outline-hidden select-none " \
                                "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                                "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :radio_item, "cn-context-menu-radio-item relative flex cursor-default items-center " \
                             "outline-hidden select-none data-[disabled]:pointer-events-none " \
                             "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :label, "cn-context-menu-label"

        element :separator, "cn-context-menu-separator"

        element :shortcut, "cn-context-menu-shortcut"

        element :sub_trigger, "cn-context-menu-sub-trigger flex cursor-default items-center " \
                              "outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :sub_content, "cn-context-menu-subcontent z-50 " \
                              "origin-(--radix-context-menu-content-transform-origin) overflow-hidden"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it context-menu-item-indicator - the self-identification rule).
        element :item_indicator, "cn-context-menu-item-indicator pointer-events-none absolute " \
                                 "flex items-center justify-center"

        # POETRY ADDITION (family convention): the indicator stays in the
        # DOM; the parent item's data-checked/data-unchecked pair drives
        # visibility.
        element :item_indicator_state, "[[data-unchecked]>&]:hidden"

        # The source's inline lucide icon classes, named per part. DELTA:
        # the context sub chevron is a bare ml-auto (the item's [&_svg]
        # rules provide size-4).
        element :indicator_check, "size-4"
        element :indicator_circle, "size-2 fill-current"
        element :sub_indicator, "ml-auto"
      end
    end
  end
end
