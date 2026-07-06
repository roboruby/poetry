# frozen_string_literal: true

module Poetry
  module Ui
    module Pagination
      # Re-expressed through the cn-* theme layer (N11). The page links
      # reuse Button styling; the nav root and the responsive label pair
      # (hidden sm:block - a split-side responsive pair, kept together
      # inline) stay utility-only.
      class Style < Poetry::Core::Style
        base "mx-auto flex w-full justify-center"

        element :content, "cn-pagination-content flex items-center"
        element :ellipsis, "cn-pagination-ellipsis flex items-center justify-center"
        # The label span on prev/next: hidden below sm (icon-only on mobile).
        element :label, "hidden sm:block"
      end
    end
  end
end
