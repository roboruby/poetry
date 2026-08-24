# frozen_string_literal: true

module Poetry
  module Ui
    module ScrollArea
      # Style dictionary for the ScrollArea family: overflow-auto +
      # scrollbar-width/scrollbar-color (Baseline CSS) style the native
      # scrollbars, so no scrollbar/thumb part dictionaries exist.
      class Style < Poetry::Core::Style
        base "relative"

        element :viewport, "size-full rounded-[inherit] transition-[color,box-shadow] outline-none " \
                           "focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 " \
                           "overflow-auto [scrollbar-width:thin] " \
                           "[scrollbar-color:var(--color-border)_transparent]"
      end
    end
  end
end
