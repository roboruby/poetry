# frozen_string_literal: true

module Poetry
  module Ui
    module Kbd
      # shadcn Kbd (base-vega), source-exact: a keyboard-key chip. The
      # in-data-[slot=tooltip-content] variants invert it inside a tooltip.
      class Style < Poetry::Core::Style
        base "pointer-events-none inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm " \
             "bg-muted px-1 font-sans text-xs font-medium text-muted-foreground select-none " \
             "in-data-[slot=tooltip-content]:bg-background/20 in-data-[slot=tooltip-content]:text-background " \
             "dark:in-data-[slot=tooltip-content]:bg-background/10 [&_svg:not([class*='size-'])]:size-3"
      end
    end
  end
end
