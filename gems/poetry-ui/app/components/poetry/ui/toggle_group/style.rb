# frozen_string_literal: true

module Poetry
  module Ui
    module ToggleGroup
      # The ToggleGroup dictionary - shadcn new-york-v4 toggle-group.tsx,
      # source-validated 2026-07-03 (ToggleGroup). This
      # dictionary carries ONLY the group root and the per-item OVERRIDES -
      # the item's variant/size classes come from Toggle::Style (shadcn's
      # `toggleVariants` import graph, shared-not-copied so the next shadcn
      # sync can't skew the two).
      #
      # KEPT source-exact but FLAGGED: the
      # data-[spacing=default]:...:shadow-xs selector is DEAD in source
      # (spacing is numeric, never "default") - ported verbatim for parity,
      # revisit on the next shadcn sync. DROPPED from source: the
      # group/toggle-group marker - source ships it with ZERO
      # group-*/toggle-group consumers (future-proofing for caller cn()
      # extensions), so Tailwind emits no rule for it and the compiled-CSS
      # verify gate rightly rejects it; restore it the moment a consumer
      # variant lands.
      class Style < Poetry::Core::Style
        base "flex w-fit items-center gap-[--spacing(var(--gap))] rounded-md " \
             "data-[spacing=default]:data-[variant=outline]:shadow-xs"

        # The item overrides over Toggle's classes: w-auto/min-w-0 relax the
        # square-ish standalone shape, focus z-index lets the ring paint
        # OVER adjacent joined segments, and the data-[spacing=0] chain is
        # the segmented control (joined corners + collapsed outline borders).
        element :item, "w-auto min-w-0 shrink-0 px-3 focus:z-10 focus-visible:z-10 " \
                       "data-[spacing=0]:rounded-none data-[spacing=0]:shadow-none " \
                       "data-[spacing=0]:first:rounded-l-md data-[spacing=0]:last:rounded-r-md " \
                       "data-[spacing=0]:data-[variant=outline]:border-l-0 " \
                       "data-[spacing=0]:data-[variant=outline]:first:border-l"
      end
    end
  end
end
