# frozen_string_literal: true

module Poetry
  module Ui
    module ClipboardText
      # Utility-only: InputGroup + Input + Button wear the chrome (the
      # SearchField composition - zero new theme CSS). The input goes mono
      # for value legibility; the stacked copy/check glyphs swap on the
      # root's data-copied stamp (structural visibility, not design).
      class Style < Poetry::Core::Style
        base "flex w-full flex-col"

        element :input, "font-mono"

        element :icon_stack, "relative flex size-4 items-center justify-center"
        element :icon_copy, "absolute inset-0 transition-all duration-200 " \
                            "[[data-copied]_&]:scale-0 [[data-copied]_&]:opacity-0"
        element :icon_check, "absolute inset-0 scale-0 opacity-0 transition-all duration-200 " \
                             "[[data-copied]_&]:scale-100 [[data-copied]_&]:opacity-100"
      end
    end
  end
end
