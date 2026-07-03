# frozen_string_literal: true

module Poetry
  module Ui
    module ContextMenu
      # The ContextMenu dictionary - shadcn new-york-v4, source-validated
      # 2026-07-02 (ContextMenu). Class strings are
      # source-exact per part. The family deltas vs DropdownMenu's
      # dictionary are the source's own: context-menu-namespaced popper
      # vars, text-foreground on the label, no gap-2 on the sub-trigger,
      # and a bare ml-auto chevron. The trigger SURFACE ships no classes
      # (shadcn passes the Radix trigger through unstyled).
      class Style < Poetry::Core::Style
        element :content, "z-50 max-h-(--radix-context-menu-content-available-height) min-w-[8rem] " \
                          "origin-(--radix-context-menu-content-transform-origin) overflow-x-hidden " \
                          "overflow-y-auto rounded-md border bg-popover p-1 text-popover-foreground shadow-md " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
                          "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
                          "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"

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

        # DELTA vs dropdown-menu: the source adds text-foreground here.
        element :label, "px-2 py-1.5 text-sm font-medium text-foreground data-[inset]:pl-8"

        element :separator, "-mx-1 my-1 h-px bg-border"

        element :shortcut, "ml-auto text-xs tracking-widest text-muted-foreground"

        # DELTA vs dropdown-menu: the source omits gap-2 on this part.
        element :sub_trigger, "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm " \
                              "outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                              "data-[inset]:pl-8 data-[state=open]:bg-accent " \
                              "data-[state=open]:text-accent-foreground [&_svg]:pointer-events-none " \
                              "[&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                              "[&_svg:not([class*='text-'])]:text-muted-foreground"

        element :sub_content, "z-50 min-w-[8rem] origin-(--radix-context-menu-content-transform-origin) " \
                              "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
                              "shadow-lg data-[side=bottom]:slide-in-from-top-2 " \
                              "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
                              "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
                              "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 " \
                              "data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
                              "data-[state=open]:zoom-in-95"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it context-menu-item-indicator - the self-identification rule).
        element :item_indicator, "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

        # POETRY ADDITION (family convention): the indicator stays in the
        # DOM; the parent item's data-state drives visibility.
        element :item_indicator_state, "[[data-state=unchecked]>&]:hidden"

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
