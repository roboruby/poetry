# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # The RadioGroup dictionary - shadcn new-york-v4 radio-group.tsx,
      # source-validated 2026-07-03 (RadioGroup). Root
      # and item strings are source-exact (grid gap-3; the aspect-square
      # size-4 rounded-full well with the suite 3px focus ring and the
      # aria-invalid destructive hooks), the indicator/dot pair is the
      # RadioGroupPrimitive.Indicator + CircleIcon markup verbatim. Two
      # poetry additions: :input (the hidden native radio - the form
      # bridge, sr-only) and :row (the demo's item+Label pairing row,
      # radio-group-demo's "flex items-center gap-3").
      class Style < Poetry::Core::Style
        base "grid gap-3"

        element :item, "aspect-square size-4 shrink-0 rounded-full border border-input text-primary " \
                       "shadow-xs transition-[color,box-shadow] outline-none " \
                       "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                       "disabled:cursor-not-allowed disabled:opacity-50 " \
                       "aria-invalid:border-destructive aria-invalid:ring-destructive/20 " \
                       "dark:bg-input/30 dark:aria-invalid:ring-destructive/40"

        element :indicator, "relative flex items-center justify-center"

        # The checked dot (source: CircleIcon size-2 fill-primary, centered
        # absolutely inside the indicator).
        element :dot, "absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 fill-primary"

        # The form participant: one hidden native radio PER item, shared
        # name - out of the Tab order and the accessibility tree (the
        # role=radio button is the accessible control).
        element :input, "sr-only"

        # The item+Label pairing row (radio-group-demo parity) rendered
        # when an item passes label:.
        element :row, "flex items-center gap-3"
      end
    end
  end
end
