# frozen_string_literal: true

module Poetry
  module Ui
    module Toggle
      # The Toggle dictionary - shadcn new-york-v4 toggle.tsx,
      # source-validated 2026-07-03 (Toggle): the
      # family's only true cva (variant default|outline x size
      # default|sm|lg), exported in source as `toggleVariants` and imported
      # by toggle-group. Poetry ports that import graph as THIS shared
      # dictionary - ToggleGroup items consume it through Toggle::Style.css
      # (shared, never copied, so the next shadcn sync can't skew the two).
      #
      # NOTE hover uses MUTED (hover:bg-muted) not accent - deliberately
      # different from Button ghost; the pressed state owns accent so
      # hover-vs-pressed stays distinguishable. Outline's hover DOES use
      # accent (source-exact).
      class Style < Poetry::Core::Style
        base "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium " \
             "whitespace-nowrap transition-[color,box-shadow] outline-none " \
             "hover:bg-muted hover:text-muted-foreground " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "disabled:pointer-events-none disabled:opacity-50 " \
             "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
             "data-pressed:bg-accent data-pressed:text-accent-foreground " \
             "dark:aria-invalid:ring-destructive/40 " \
             "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

        variant :variant, {
          default: "bg-transparent",
          outline: "border border-input bg-transparent shadow-xs hover:bg-accent hover:text-accent-foreground"
        }

        # min-w-* keeps icon-only toggles square-ish.
        variant :size, {
          default: "h-9 min-w-9 px-2",
          sm: "h-8 min-w-8 px-1.5",
          lg: "h-10 min-w-10 px-2.5"
        }
      end
    end
  end
end
