# frozen_string_literal: true

module Poetry
  module Ui
    module Table
      # shadcn Table (base-vega), source-exact. Zero JS - the row's selected
      # state is the Base UI vocabulary (data-selected): a consumer
      # (or DataTable) sets it; the class styles it.
      class Style < Poetry::Core::Style
        base "w-full caption-bottom text-sm"

        element :container, "relative w-full overflow-x-auto"
        element :header, "[&_tr]:border-b"
        element :body, "[&_tr:last-child]:border-0"
        element :footer, "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0"
        element :row, "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 " \
                      "data-selected:bg-muted"
        element :head, "h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground " \
                       "[&:has([role=checkbox])]:pr-0"
        element :cell, "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0"
        element :caption, "mt-4 text-sm text-muted-foreground"
      end
    end
  end
end
