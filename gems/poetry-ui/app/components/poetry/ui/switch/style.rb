# frozen_string_literal: true

module Poetry
  module Ui
    module Switch
      # The Switch dictionary - shadcn new-york-v4 switch.tsx,
      # source-validated 2026-07-03 (Switch). The size
      # variant travels ENTIRELY by data attribute (data-[size=*] on the
      # track, group-data-[size=*]/switch on the thumb) - the suite's first
      # data-attribute-carried variant, so the :size style declares no
      # variant mapping here. One poetry addition on the thumb: the rtl:
      # travel fix (shadcn's translate-x is physical/LTR-only - under RTL
      # the knob must still travel toward the "on" end).
      class Style < Poetry::Core::Style
        base "peer group/switch inline-flex shrink-0 items-center rounded-full border border-transparent " \
             "shadow-xs transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] " \
             "focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 " \
             "data-[size=default]:h-[1.15rem] data-[size=default]:w-8 " \
             "data-[size=sm]:h-3.5 data-[size=sm]:w-6 " \
             "data-checked:bg-primary data-unchecked:bg-input " \
             "dark:data-unchecked:bg-input/80"

        element :thumb, "pointer-events-none block rounded-full bg-background ring-0 transition-transform " \
                        "group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 " \
                        "data-checked:translate-x-[calc(100%-2px)] data-unchecked:translate-x-0 " \
                        "rtl:data-checked:-translate-x-[calc(100%-2px)] " \
                        "dark:data-checked:bg-primary-foreground dark:data-unchecked:bg-foreground"

        # The form participant + the store (the Checkbox architecture).
        element :input, "sr-only"
      end
    end
  end
end
