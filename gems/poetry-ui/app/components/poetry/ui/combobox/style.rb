# frozen_string_literal: true

module Poetry
  module Ui
    module Combobox
      # The Combobox dictionary - the shadcn new-york-v4 DOCS composition
      # (combobox-demo.tsx: Button variant=outline role=combobox +
      # ChevronsUpDown + Popover w-[200px] p-0 + Command h-9 input),
      # source-validated 2026-07-03 (Combobox). The
      # embedded Command parts reuse Command::Style VERBATIM (the engine's
      # dictionary is not duplicated here); this dictionary owns only the
      # SHELL parts plus the two demo retunes (the h-9 input scale, the
      # trailing check indicator).
      class Style < Poetry::Core::Style
        # The demo trigger IS the golden Button (base + outline + default
        # size) with three demo deltas: justify-between (the value/chevron
        # split replaces justify-center), font-normal (a value display,
        # not a button label), and the w-[200px] demo width (overridden by
        # the width: knob through the class merger). Poetry additions:
        # data-[placeholder]:text-muted-foreground (Select's placeholder
        # dim - the aria-invalid destructive chain rides Button base).
        element :trigger, "inline-flex h-9 w-[200px] shrink-0 items-center justify-between gap-2 " \
                          "rounded-md border bg-background px-4 py-2 text-sm font-normal " \
                          "whitespace-nowrap shadow-xs transition-all outline-none " \
                          "hover:bg-accent hover:text-accent-foreground " \
                          "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                          "disabled:pointer-events-none disabled:opacity-50 " \
                          "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
                          "data-[placeholder]:text-muted-foreground " \
                          "dark:aria-invalid:ring-destructive/40 dark:border-input dark:bg-input/30 " \
                          "dark:hover:bg-input/50 has-[>svg]:px-3 " \
                          "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

        # The value DISPLAY truncates inside the fixed-width trigger.
        element :value, "truncate"

        # The popup: Popover's chrome (source-exact) retuned per the demo -
        # p-0 (the Command brings its own padding) and the anchor-width
        # binding (the demo's w-[200px] PopoverContent becomes "track the
        # trigger" - one width knob, two surfaces; popper measures the
        # anchor and sets the generic var).
        element :content, "z-50 w-(--radix-popper-anchor-width) origin-(--radix-popper-transform-origin) " \
                          "rounded-md border bg-popover p-0 text-popover-foreground shadow-md outline-hidden " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-closed:animate-out data-closed:fade-out-0 " \
                          "data-closed:zoom-out-95 data-open:animate-in " \
                          "data-open:fade-in-0 data-open:zoom-in-95"

        # The demo's CommandInput className="h-9" retune, merged over
        # Command's own :input string (h-10 -> h-9 via the class merger).
        element :input_scale, "h-9"

        # The committed-value check: TRAILING ml-auto per the demo (not
        # Select's absolute right-2 gutter) - written logical (ms-auto),
        # the family RTL fix Command's shortcut already took over source.
        element :item_indicator, "ms-auto flex size-4 items-center justify-center"

        # POETRY ADDITION (Select's precedent): the demo toggles the check
        # by opacity-per-value-equality in JSX; poetry server-renders it
        # always and the parent item's bare data-selected drives visibility
        # (unselected = attribute ABSENCE - no data-unselected exists), so
        # the controller's aria-selected/data-selected twin-flip is the
        # whole toggle.
        element :item_indicator_state, "[:not([data-selected])>&]:hidden"

        # The form bubble: visually hidden but PAINTED (sr-only clips,
        # never display:none - autofill heuristics skip unpainted controls).
        element :native, "sr-only"

        # The source's inline lucide icon classes, named per part. The
        # double chevron is the combobox tell (Select wears chevron-down).
        element :trigger_icon, "size-4 opacity-50"
        element :indicator_check, "size-4"
      end
    end
  end
end
