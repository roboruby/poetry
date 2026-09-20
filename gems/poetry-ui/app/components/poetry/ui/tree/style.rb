# frozen_string_literal: true

module Poetry
  module Ui
    module Tree
      # Utility-only (the Separator/Spinner rule): rows indent off the
      # server-stamped --poetry-tree-level custom property, the chevron
      # rotates on the row's data-expanded (group-scoped), and focus rides
      # a ring on the row itself. data-slot selectors are the restyle seam.
      class Style < Poetry::Core::Style
        base "flex w-full flex-col gap-px outline-none"

        element :item, "group/tree-item flex cursor-default items-center gap-1.5 rounded-md " \
                       "py-1.5 pr-2 text-sm outline-none " \
                       "pl-[calc(0.5rem+(var(--poetry-tree-level)-1)*1.25rem)] " \
                       "hover:bg-accent/50 " \
                       "focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                       "data-disabled:pointer-events-none data-disabled:opacity-50"
        element :cell, "contents"
        element :toggle, "inline-flex size-4 shrink-0 items-center justify-center rounded-sm " \
                         "text-muted-foreground outline-none transition-transform " \
                         "group-data-[expanded]/tree-item:rotate-90 [&_svg]:size-3.5"
        # Leaves keep the chevron's footprint so labels align across levels.
        element :toggle_spacer, "inline-flex size-4 shrink-0"
        element :label, "truncate text-foreground no-underline"
      end
    end
  end
end
