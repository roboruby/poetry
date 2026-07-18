# frozen_string_literal: true

module Poetry
  module Ui
    module Table
      # Re-expressed through the cn-* theme layer (N11). Zero JS - the
      # row's selected state stays the Base UI vocabulary (data-selected),
      # its tint now in the theme with every other row tint (same-side).
      # The scroll container stays utility-only (pure mechanism).
      class Style < Poetry::Core::Style
        base "cn-table"

        element :container, "relative w-full overflow-x-auto"
        element :container_sticky,
                "overflow-y-auto [&_thead]:sticky [&_thead]:top-0 [&_thead]:z-10 [&_thead]:bg-background"
        element :header, "cn-table-header"
        element :body, "cn-table-body"
        element :footer, "cn-table-footer"
        element :row, "cn-table-row transition-colors"
        element :head, "cn-table-head"
        element :cell, "cn-table-cell"
        element :caption, "cn-table-caption"
      end
    end
  end
end
