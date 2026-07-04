# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      # The root is a non-visual wrapper; the visual surface is the native
      # <dialog> element (the :content element), centered by the top layer,
      # its backdrop styled via the backdrop: variant.
      class Style < Poetry::Core::Style
        # open:grid, NOT grid: a bare display class would defeat the UA's
        # dialog:not([open]) { display: none } and render the dialog inline
        # while closed (caught by the 2026-07-01 browser pass - invisible
        # to jsdom, which has no UA stylesheet).
        element :content, "relative m-auto open:grid w-full max-w-[calc(100%-2rem)] gap-4 rounded-lg border " \
                          "bg-background p-6 text-foreground shadow-lg sm:max-w-lg " \
                          "backdrop:bg-black/50 data-open:animate-in data-open:fade-in-0 " \
                          "data-open:zoom-in-95"

        element :header, "flex flex-col gap-2 text-center sm:text-left"
        element :title, "text-lg font-semibold leading-none"
        element :description, "text-sm text-muted-foreground"
        element :footer, "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
        element :close, "absolute top-4 right-4"
      end
    end
  end
end
