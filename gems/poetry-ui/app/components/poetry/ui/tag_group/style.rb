# frozen_string_literal: true

module Poetry
  module Ui
    module TagGroup
      # Utility-only (the Separator/Spinner rule): chips wear the secondary
      # badge treatment in structural utilities on semantic tokens - no
      # upstream cn hook exists for a tag group; data-slot selectors are
      # the restyle seam. The grid carries a focus ring for its empty-state
      # tab-stop role.
      class Style < Poetry::Core::Style
        base "flex w-fit flex-col gap-1.5"

        element :label, "text-sm font-medium"
        element :grid, "flex flex-wrap items-center gap-1.5 rounded-md outline-none " \
                       "focus-visible:ring-[3px] focus-visible:ring-ring/50"
        element :tag, "inline-flex items-center gap-1 rounded-md border border-transparent " \
                      "bg-secondary px-2 py-0.5 text-xs font-medium text-secondary-foreground " \
                      "outline-none focus-visible:border-ring focus-visible:ring-[3px] " \
                      "focus-visible:ring-ring/50 " \
                      "data-disabled:pointer-events-none data-disabled:opacity-50"
        element :cell, "contents"
        element :remove, "-mr-0.5 inline-flex size-3.5 items-center justify-center rounded-sm " \
                         "opacity-60 outline-none hover:opacity-100 " \
                         "focus-visible:ring-2 focus-visible:ring-ring/50 [&_svg]:size-3"
      end
    end
  end
end
