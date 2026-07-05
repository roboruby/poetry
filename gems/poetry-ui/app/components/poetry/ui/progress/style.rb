# frozen_string_literal: true

module Poetry
  module Ui
    module Progress
      # shadcn Progress (base-vega), source-exact.
      class Style < Poetry::Core::Style
        base "flex flex-wrap gap-3"

        element :track, "relative flex h-1.5 w-full items-center overflow-x-hidden rounded-full bg-muted"
        element :indicator, "h-full bg-primary transition-all"
        element :label, "text-sm font-medium"
        element :value, "ml-auto text-sm text-muted-foreground tabular-nums"
      end
    end
  end
end
