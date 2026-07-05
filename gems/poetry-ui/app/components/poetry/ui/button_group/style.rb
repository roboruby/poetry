# frozen_string_literal: true

module Poetry
  module Ui
    module ButtonGroup
      # shadcn ButtonGroup (base-vega), source-exact. The separator's
      # data-horizontal/vertical selectors are the N6 bridge orientation
      # variants (they match the data-orientation the Separator emits).
      class Style < Poetry::Core::Style
        base "flex w-fit items-stretch *:focus-visible:relative *:focus-visible:z-10 " \
             "has-[>[data-slot=button-group]]:gap-2 " \
             "has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-md " \
             "[&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1"

        variant :orientation, {
          horizontal: "*:data-slot:rounded-r-none [&>[data-slot]:not(:has(~[data-slot]))]:rounded-r-md! " \
                      "[&>[data-slot]~[data-slot]]:rounded-l-none [&>[data-slot]~[data-slot]]:border-l-0",
          vertical: "flex-col *:data-slot:rounded-b-none [&>[data-slot]:not(:has(~[data-slot]))]:rounded-b-md! " \
                    "[&>[data-slot]~[data-slot]]:rounded-t-none [&>[data-slot]~[data-slot]]:border-t-0"
        }

        element :text, "flex items-center gap-2 rounded-md border bg-muted px-2.5 text-sm font-medium " \
                       "shadow-xs [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"
        element :separator, "relative self-stretch bg-input data-horizontal:mx-px data-horizontal:w-auto " \
                            "data-vertical:my-px data-vertical:h-auto"
      end
    end
  end
end
