# frozen_string_literal: true

module Poetry
  module Ui
    module Stat
      # Utility-only (the Separator/Spinner rule): no upstream cn hook
      # exists for a Stat, so the whole surface is structural utilities on
      # semantic tokens - data-slot selectors remain the always-on restyle
      # seam, and cn names arrive only when a theme wants to own this look.
      class Style < Poetry::Core::Style
        base "flex min-w-0 flex-col gap-1.5"

        element :label, "text-sm text-muted-foreground"
        element :row, "flex flex-wrap items-baseline gap-x-2 gap-y-1"
        element :value, "text-3xl font-semibold tracking-tight tabular-nums"
        element :delta, "inline-flex items-center gap-1 text-sm font-medium tabular-nums " \
                        "[&_svg]:size-3.5 [&_svg]:shrink-0"
        # Theme-owned (the Badge status-trio precedent): the
        # AA-safe success text needs a derived-lightness treatment, and an
        # arbitrary oklch utility in the DICTIONARY would trip the
        # no_raw_colors gate on every consumer page - the design lives in
        # the nine theme files under this one name.
        element :delta_positive, "cn-stat-delta-positive"
        element :delta_negative, "text-destructive"
        element :delta_neutral, "text-muted-foreground"
        element :description, "text-sm text-muted-foreground"
        element :media, "pt-1"
      end
    end
  end
end
