# frozen_string_literal: true

module Poetry
  module Ui
    module Select
      # The Select dictionary - shadcn new-york-v4, source-validated
      # 2026-07-03 (Select). Class strings are
      # source-exact per part with ONE deliberate delta: poetry is
      # POPPER-ONLY (Radix's item-aligned overlay mode is not ported), so
      # the source's popper-conditional classes (the per-side translate
      # nudges on :content and the trigger-size viewport binding on
      # :viewport) are baked in unconditionally. Poetry additions:
      # :item_indicator_state (React unmounts the indicator; poetry
      # server-renders it and the item's data-state hides it), :native
      # (the visually-hidden form bubble - sr-only, never display:none,
      # autofill needs a painted control), and the named icon sizes the
      # source inlined on its lucide elements.
      class Style < Poetry::Core::Style
        element :trigger, "flex w-fit items-center justify-between gap-2 rounded-md border border-input " \
                          "bg-transparent px-3 py-2 text-sm whitespace-nowrap shadow-xs " \
                          "transition-[color,box-shadow] outline-none focus-visible:border-ring " \
                          "focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed " \
                          "disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
                          "data-[placeholder]:text-muted-foreground data-[size=default]:h-9 data-[size=sm]:h-8 " \
                          "*:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex " \
                          "*:data-[slot=select-value]:items-center *:data-[slot=select-value]:gap-2 " \
                          "dark:bg-input/30 dark:hover:bg-input/50 dark:aria-invalid:ring-destructive/40 " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                          "[&_svg:not([class*='text-'])]:text-muted-foreground"

        element :content, "relative z-50 max-h-(--radix-select-content-available-height) min-w-[8rem] " \
                          "origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto " \
                          "rounded-md border bg-popover text-popover-foreground shadow-md " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
                          "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
                          "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 " \
                          "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 " \
                          "data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"

        element :viewport, "p-1 h-[var(--radix-select-trigger-height)] w-full " \
                           "min-w-[var(--radix-select-trigger-width)] scroll-my-1"

        element :item, "relative flex w-full cursor-default items-center gap-2 rounded-sm py-1.5 pr-8 pl-2 " \
                       "text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground " \
                       "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " \
                       "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                       "[&_svg:not([class*='text-'])]:text-muted-foreground *:[span]:last:flex " \
                       "*:[span]:last:items-center *:[span]:last:gap-2"

        element :label, "px-2 py-1.5 text-xs text-muted-foreground"

        element :separator, "pointer-events-none -mx-1 my-1 h-px bg-border"

        element :scroll_button, "flex cursor-default items-center justify-center py-1"

        # Source-exact wrapper span (named select-item-indicator in
        # new-york-v4) - the RIGHT-2 gutter, the mirror image of
        # dropdown-menu's left gutter.
        element :item_indicator, "absolute right-2 flex size-3.5 items-center justify-center"

        # POETRY ADDITION: the source renders the check only while selected
        # (Radix ItemIndicator unmounts); poetry keeps it in the DOM and the
        # parent item's data-state drives visibility, so the controller's
        # aria-selected/data-state twin-flip is the whole toggle.
        element :item_indicator_state, "[[data-state=unchecked]>&]:hidden"

        # The form bubble: visually hidden but PAINTED (sr-only clips, never
        # display:none - browser autofill heuristics skip unpainted controls).
        element :native, "sr-only"

        # The source's inline lucide icon classes, named per part.
        element :trigger_icon, "size-4 opacity-50"
        element :indicator_check, "size-4"
        element :scroll_icon, "size-4"
      end
    end
  end
end
