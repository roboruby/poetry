# frozen_string_literal: true

module Poetry
  module Ui
    module Menubar
      # The Menubar dictionary - shadcn new-york-v4, source-validated
      # 2026-07-02 (Menubar). Class strings are
      # source-exact per part, including the source's own quirks kept
      # verbatim: the content omits data-closed:animate-out,
      # checkbox/radio items round with rounded-xs (not -sm), and the
      # sub-trigger uses outline-none with no [&_svg] block. The :menu
      # wrapper class is the one poetry addition - display:contents keeps
      # the per-menu controller scope OUT of the bar's flex layout (and the
      # accessibility tree), so the DOM stays Radix-parity for both.
      class Style < Poetry::Core::Style
        base "flex h-9 items-center gap-1 rounded-md border bg-background p-1 shadow-xs"

        # POETRY ADDITION: the logical Menu grouping needs a host element
        # for its menu + popper controllers; display:contents erases it
        # from layout and the a11y tree (Radix renders no element here).
        element :menu, "contents"

        element :trigger, "flex items-center rounded-sm px-2 py-1 text-sm font-medium outline-hidden " \
                          "select-none focus:bg-accent focus:text-accent-foreground " \
                          "data-popup-open:bg-accent data-popup-open:text-accent-foreground"

        element :content, "z-50 min-w-[12rem] origin-(--radix-menubar-content-transform-origin) " \
                          "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
                          "shadow-md data-[side=bottom]:slide-in-from-top-2 " \
                          "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
                          "data-[side=top]:slide-in-from-bottom-2 data-closed:fade-out-0 " \
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

        # DELTA vs the family: rounded-xs (the source's own inconsistency).
        element :checkbox_item, "relative flex cursor-default items-center gap-2 rounded-xs py-1.5 pr-2 pl-8 " \
                                "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                                "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                                "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                                "[&_svg:not([class*='size-'])]:size-4"

        element :radio_item, "relative flex cursor-default items-center gap-2 rounded-xs py-1.5 pr-2 pl-8 " \
                             "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                             "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                             "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                             "[&_svg:not([class*='size-'])]:size-4"

        element :label, "px-2 py-1.5 text-sm font-medium data-[inset]:pl-8"

        element :separator, "-mx-1 my-1 h-px bg-border"

        element :shortcut, "ml-auto text-xs tracking-widest text-muted-foreground"

        # DELTA vs the family: outline-none (not -hidden), no [&_svg] block,
        # no gap-2 (source-exact).
        element :sub_trigger, "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm " \
                              "outline-none select-none focus:bg-accent focus:text-accent-foreground " \
                              "data-[inset]:pl-8 data-popup-open:bg-accent " \
                              "data-popup-open:text-accent-foreground"

        element :sub_content, "z-50 min-w-[8rem] origin-(--radix-menubar-content-transform-origin) " \
                              "overflow-hidden rounded-md border bg-popover p-1 text-popover-foreground " \
                              "shadow-lg data-[side=bottom]:slide-in-from-top-2 " \
                              "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
                              "data-[side=top]:slide-in-from-bottom-2 data-closed:animate-out " \
                              "data-closed:fade-out-0 data-closed:zoom-out-95 " \
                              "data-open:animate-in data-open:fade-in-0 " \
                              "data-open:zoom-in-95"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it menubar-item-indicator - the self-identification rule).
        element :item_indicator, "pointer-events-none absolute left-2 flex size-3.5 items-center justify-center"

        # POETRY ADDITION (family convention): the indicator stays in the
        # DOM; the parent item's data-checked/data-unchecked pair drives
        # visibility.
        element :item_indicator_state, "[[data-unchecked]>&]:hidden"

        # The source's inline lucide icon classes, named per part. DELTA:
        # the menubar sub chevron is ml-auto h-4 w-4 (source-exact).
        element :indicator_check, "size-4"
        element :indicator_circle, "size-2 fill-current"
        element :sub_indicator, "ml-auto h-4 w-4"
      end
    end
  end
end
