# frozen_string_literal: true

module Poetry
  module Charts
    module TooltipContent
      # shadcn ChartTooltipContent (new-york-v4 chart.tsx), source-exact.
      # The indicator's border-(--color-border)/bg-(--color-bg) arbitrary
      # properties read the per-row inline custom properties the component
      # sets to the series color.
      class Style < Poetry::Core::Style
        base "grid min-w-[8rem] items-start gap-1.5 rounded-lg border border-border/50 bg-background " \
             "px-2.5 py-1.5 text-xs shadow-xl"

        element :label, "font-medium"
        element :inner, "grid gap-1.5"
        element :row, "flex w-full flex-wrap items-stretch gap-2 [&>svg]:h-2.5 [&>svg]:w-2.5 " \
                      "[&>svg]:text-muted-foreground"
        element :row_dot, "items-center"
        element :indicator, "shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg)"
        element :indicator_dot, "h-2.5 w-2.5"
        element :indicator_line, "w-1"
        element :indicator_dashed, "w-0 border-[1.5px] border-dashed bg-transparent"
        element :indicator_dashed_nested, "my-0.5"
        element :value_wrap, "flex flex-1 justify-between leading-none"
        element :value_wrap_center, "items-center"
        element :value_wrap_end, "items-end"
        element :name, "text-muted-foreground"
        element :value, "font-mono font-medium text-foreground tabular-nums"
      end
    end
  end
end
