# frozen_string_literal: true

module Poetry
  module Ui
    module NativeSelect
      # shadcn NativeSelect (base-vega), source-exact. The chevron is
      # rendered as a positioned wrapper span around the Icon (upstream
      # classes the svg directly); the svg sizing rides the wrapper.
      class Style < Poetry::Core::Style
        # Upstream also stamps a group/native-select marker; nothing consumes
        # it (verified against the full base-vega set) - dropped like Item's
        # group/item-group; restore when a consumer lands.
        base "relative w-fit has-[select:disabled]:opacity-50"

        element :select, "h-9 w-full min-w-0 appearance-none rounded-md border border-input " \
                         "bg-transparent py-1 pr-8 pl-2.5 text-sm shadow-xs " \
                         "transition-[color,box-shadow] outline-none select-none " \
                         "selection:bg-primary selection:text-primary-foreground " \
                         "placeholder:text-muted-foreground focus-visible:border-ring " \
                         "focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none " \
                         "disabled:cursor-not-allowed aria-invalid:border-destructive " \
                         "aria-invalid:ring-3 aria-invalid:ring-destructive/20 data-[size=sm]:h-8 " \
                         "dark:bg-input/30 dark:hover:bg-input/50 dark:aria-invalid:border-destructive/50 " \
                         "dark:aria-invalid:ring-destructive/40"
        element :icon, "pointer-events-none absolute top-1/2 right-2.5 -translate-y-1/2 " \
                       "text-muted-foreground select-none [&>svg]:size-4"
        element :option, "bg-[Canvas] text-[CanvasText]"
        element :optgroup, "bg-[Canvas] text-[CanvasText]"
      end
    end
  end
end
