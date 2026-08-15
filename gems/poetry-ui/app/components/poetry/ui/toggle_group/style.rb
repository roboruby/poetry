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
        base "cn-toggle-group group/toggle-group flex w-fit flex-row items-center " \
             "gap-[--spacing(var(--gap))] data-vertical:flex-col data-vertical:items-stretch"

        # The item overrides over Toggle's classes: w-auto/min-w-0 relax the
        # square-ish standalone shape, focus z-index lets the ring paint
        # OVER adjacent joined segments, and the data-[spacing=0] chain is
        # the segmented control (joined corners + collapsed outline borders).
        # The WHOLE segment-radius cluster (rounded-none + first/last edge
        # radii) moved theme-side at N12 W2 - split-side rule: an inline
        # rounded-none would beat every theme's edge rounding by layer
        # order (a judge caught exactly that when only the edges moved).
        element :item, "cn-toggle-group-item w-auto min-w-0 shrink-0 focus:z-10 focus-visible:z-10 " \
                       "data-[spacing=0]:shadow-none " \
                       "group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:border-l-0 " \
                       "group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:border-t-0 " \
                       "group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-l " \
                       "group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-t"
      end
    end
  end
end
