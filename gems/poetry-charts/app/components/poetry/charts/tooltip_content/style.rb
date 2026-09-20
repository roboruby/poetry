# frozen_string_literal: true

module Poetry
  module Charts
    module TooltipContent
      # Re-expressed through the cn-* theme layer: the box, type,
      # and row treatments ride cn-chart-tooltip-* rules. The indicator's
      # border-(--color-border)/bg-(--color-bg) arbitrary properties stay
      # inline - they read the per-row inline custom properties the
      # component sets to the series color (mechanism).
      class Style < Poetry::Core::Style
        base "cn-chart-tooltip grid min-w-[8rem] items-start"

        element :label, "cn-chart-tooltip-label"
        element :inner, "grid gap-1.5"
        element :row, "cn-chart-tooltip-row flex w-full flex-wrap items-stretch"
        element :row_dot, "items-center"
        element :indicator, "shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg)"
        element :indicator_dot, "h-2.5 w-2.5"
        element :indicator_line, "w-1"
        element :indicator_dashed, "w-0 border-[1.5px] border-dashed bg-transparent"
        element :indicator_dashed_nested, "my-0.5"
        element :value_wrap, "flex flex-1 justify-between leading-none"
        element :value_wrap_center, "items-center"
        element :value_wrap_end, "items-end"
        element :name, "cn-chart-tooltip-name"
        element :value, "cn-chart-tooltip-value"
      end
    end
  end
end
