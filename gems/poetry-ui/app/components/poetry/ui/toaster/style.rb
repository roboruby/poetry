# frozen_string_literal: true

module Poetry
  module Ui
    module Toaster
      # Re-expressed through the cn-* theme layer (N11). The position
      # variants stay INLINE, unnamed: corner placement is pure positioning
      # mechanism (fixed-corner geometry the slide selectors key on), with
      # zero conflicts against the themed spacing/width.
      class Style < Poetry::Core::Style
        # max-w-full rides the theme WITH its sm: cap (split-side rule for
        # responsive pairs - inline it would beat the themed cap always).
        base "cn-toaster group/toaster pointer-events-none fixed z-50 flex w-full flex-col"

        variant :position, {
          "top-left": "top-0 left-0",
          "top-center": "top-0 left-1/2 -translate-x-1/2",
          "top-right": "top-0 right-0",
          "bottom-left": "bottom-0 left-0",
          "bottom-center": "bottom-0 left-1/2 -translate-x-1/2",
          "bottom-right": "bottom-0 right-0"
        }
      end
    end
  end
end
