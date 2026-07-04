# frozen_string_literal: true

module Poetry
  module Ui
    module DropdownMenu
      # The DropdownMenu dictionary - shadcn new-york-v4, source-validated
      # 2026-07-02 (DropdownMenu). Class strings are
      # source-exact per part; the only poetry additions are the indicator
      # visibility switch (:item_indicator_state - React conditionally
      # renders the indicator, poetry server-renders it and lets the item's
      # data-unchecked hide it) and the named icon sizes the source inlined on
      # its lucide elements.
      class Style < Poetry::Core::Style
        element :content, "z-50 max-h-(--radix-dropdown-menu-content-available-height) min-w-[8rem] " \
                          "origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden " \
                          "overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground shadow-md " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-closed:animate-out data-closed:fade-out-0 " \
                          "data-closed:zoom-out-95 data-open:animate-in " \
                          "data-open:fade-in-0 data-open:zoom-in-95"

        element :item, "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
                       "outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                       "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 data-[inset]:pl-8 " \
                       "data-[variant=destructive]:text-destructive " \
                       "data-[variant=destructive]:focus:bg-destructive/10 " \
                       "data-[variant=destructive]:focus:text-destructive " \
                       "dark:data-[variant=destructive]:focus:bg-destructive/20 " \
                       "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                       "[&_svg:not([class*='text-'])]:text-muted-foreground " \
                       "data-[variant=destructive]:*:[svg]:text-destructive!"

        element :checkbox_item, "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 " \
                                "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                                "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                                "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                                "[&_svg:not([class*='size-'])]:size-4"

        element :radio_item, "relative flex cursor-default items-center gap-2 rounded-sm py-1.5 pr-2 pl-8 " \
                             "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                             "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                             "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                             "[&_svg:not([class*='size-'])]:size-4"

        element :label, "px-2 py-1.5 text-sm font-medium data-[inset]:pl-8"

        element :separator, "-mx-1 my-1 h-px bg-border"

        element :shortcut, "ml-auto text-xs tracking-widest text-muted-foreground"

        element :sub_trigger, "flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm " \
                              "outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                              "data-[inset]:pl-8 data-popup-open:bg-accent " \
                              "data-popup-open:text-accent-foreground [&_svg]:pointer-events-none " \
                              "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                              "[&_svg:not([class*='text-'])]:text-muted-foreground"

        element :sub_content, "z-50 min-w-[8rem] origin-(--radix-dropdown-menu-content-transform-origin) " \
                              "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
                              "shadow-lg data-[side=bottom]:slide-in-from-top-2 " \
                              "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
                              "data-[side=top]:slide-in-from-bottom-2 data-closed:animate-out " \
                              "data-closed:fade-out-0 data-closed:zoom-out-95 " \
                              "data-open:animate-in data-open:fade-in-0 " \
                              "data-open:zoom-in-95"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it dropdown-menu-item-indicator - the self-identification rule).
        element :item_indicator, "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

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
