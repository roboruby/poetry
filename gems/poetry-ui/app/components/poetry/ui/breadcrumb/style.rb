# frozen_string_literal: true

module Poetry
  module Ui
    module Breadcrumb
      # shadcn Breadcrumb (base-vega), source-exact (the separator chevron's
      # cn-rtl-flip dropped like pagination's - the cn-* theme layer is its
      # own milestone).
      class Style < Poetry::Core::Style
        base ""

        element :list, "flex flex-wrap items-center gap-1.5 text-sm wrap-break-word " \
                       "text-muted-foreground sm:gap-2.5"
        element :item, "inline-flex items-center gap-1.5"
        element :link, "transition-colors hover:text-foreground"
        element :page, "font-normal text-foreground"
        element :separator, "[&>svg]:size-3.5"
        element :ellipsis, "flex size-5 items-center justify-center [&>svg]:size-4"
      end
    end
  end
end
