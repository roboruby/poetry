# frozen_string_literal: true

module Poetry
  module Ui
    module ToggleGroup
      # Re-expressed through the cn-* theme layer (N11). The gap mechanism
      # (gap-[--spacing(var(--gap))]) and the whole data-[spacing=0]
      # segmented-control chain stay inline - upstream's own split keeps
      # the segmentation machinery in markup; the group radius + the
      # flagged-dead shadow selector ride the theme. Item variant/size
      # classes still come from Toggle::Style (shared, never copied).
      class Style < Poetry::Core::Style
        base "cn-toggle-group flex w-fit items-center gap-[--spacing(var(--gap))]"

        # The item overrides over Toggle's classes: w-auto/min-w-0 relax the
        # square-ish standalone shape, focus z-index lets the ring paint
        # OVER adjacent joined segments, and the data-[spacing=0] chain is
        # the segmented control (joined corners + collapsed outline borders).
        # The first/last EDGE radii moved theme-side at N12 W2 (each theme
        # rounds its segments in its own radius language - nova lg, rhea
        # 2xl); rounded-none + the border collapse stay inline (invariant).
        element :item, "cn-toggle-group-item w-auto min-w-0 shrink-0 focus:z-10 focus-visible:z-10 " \
                       "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none " \
                       "data-[spacing=0]:data-[variant=outline]:border-l-0 " \
                       "data-[spacing=0]:data-[variant=outline]:first:border-l"
      end
    end
  end
end
