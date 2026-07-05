# frozen_string_literal: true

module Poetry
  module Ui
    module ScrollArea
      # shadcn ScrollArea (base-vega) root/viewport, source-exact - plus the
      # native-scrollbar deviation (the W3 decision): overflow-auto +
      # scrollbar-width/scrollbar-color (Baseline CSS) replace Base UI's JS
      # scrollbar/thumb parts, so those part dictionaries are deliberately
      # not ported.
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
