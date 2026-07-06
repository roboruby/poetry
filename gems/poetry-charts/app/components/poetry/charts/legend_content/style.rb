# frozen_string_literal: true

module Poetry
  module Charts
    module LegendContent
      # shadcn ChartLegendContent (new-york-v4 chart.tsx), source-exact.
      class Style < Poetry::Core::Style
        # flex-wrap is poetry's one addition to the shadcn base: the legend
        # lives in a real flex column with the SVG, so long item lists wrap
        # instead of clipping at the container edge (upstream reaches for a
        # per-block flex-wrap className for the same case).
        base "flex flex-wrap items-center justify-center gap-4"

        # The padding sits on the side facing the chart (shadcn's
        # verticalAlign rule); order-first lifts a top legend above the SVG
        # inside the container's flex column.
        variant :align, {
          top: "pb-3 order-first",
          bottom: "pt-3"
        }
        element :item, "flex items-center gap-1.5 [&>svg]:h-3 [&>svg]:w-3 [&>svg]:text-muted-foreground"
        element :swatch, "h-2 w-2 shrink-0 rounded-[2px]"
        # Toggle buttons dim when their series hides (the live controller
        # stamps data-hidden).
        element :toggle, "cursor-pointer data-hidden:opacity-40"
      end
    end
  end
end
