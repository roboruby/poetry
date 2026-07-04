# frozen_string_literal: true

module Poetry
  module Ui
    module Checkbox
      # The Checkbox dictionary - shadcn new-york-v4 checkbox.tsx,
      # source-validated 2026-07-03 (Checkbox). The
      # control string is source-exact (size-4 well, transition-shadow,
      # data-checked primary fill, the suite 3px focus ring,
      # aria-invalid destructive hooks, dark:bg-input/30). Two poetry
      # additions on the indicator: data-unchecked:invisible keeps
      # it in the DOM CSS-hidden (Radix unmounts via Presence; source is
      # transition-none - there is no exit animation to await) and
      # data-indeterminate never needs extra classes (the icon
      # swap is render-time). The input element is the sr-only store.
      class Style < Poetry::Core::Style
        base "peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs transition-shadow " \
             "outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "disabled:cursor-not-allowed disabled:opacity-50 " \
             "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
             "data-checked:border-primary data-checked:bg-primary " \
             "data-checked:text-primary-foreground dark:bg-input/30 " \
             "dark:aria-invalid:ring-destructive/40 dark:data-checked:bg-primary"

        element :indicator, "grid place-content-center text-current transition-none " \
                            "data-unchecked:invisible"

        # The check/minus glyph size (source: CheckIcon className="size-3.5").
        element :icon, "size-3.5"

        # The form participant + the store: visually hidden, out of the
        # accessibility tree (the button is the accessible control).
        element :input, "sr-only"
      end
    end
  end
end
