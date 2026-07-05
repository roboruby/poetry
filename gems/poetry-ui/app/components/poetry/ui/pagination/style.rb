# frozen_string_literal: true

module Poetry
  module Ui
    module Pagination
      # shadcn Pagination (base-vega), source-exact. The page links reuse the
      # Button styling (outline when active, ghost otherwise); this dictionary
      # holds only the nav / list / ellipsis chrome.
      class Style < Poetry::Core::Style
        base "mx-auto flex w-full justify-center"

        element :content, "flex items-center gap-1"
        element :ellipsis, "flex size-9 items-center justify-center [&_svg:not([class*='size-'])]:size-4"
        # The label span on prev/next: hidden below sm (icon-only on mobile).
        element :label, "hidden sm:block"
      end
    end
  end
end
