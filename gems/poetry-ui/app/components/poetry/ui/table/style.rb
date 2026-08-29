# frozen_string_literal: true

module Poetry
  module Ui
    module Table
      # Re-expressed through the cn-* theme layer. Zero JS - the row's
      # selected state travels as data-selected, its tint in the theme
      # with every other row tint. The scroll container carries its own
      # themed hook (cn-table-container).
      class Style < Poetry::Core::Style
        base "cn-table"

        element :container, "cn-table-container"
        element :container_sticky,
                "overflow-y-auto [&_thead]:sticky [&_thead]:top-0 [&_thead]:z-10 [&_thead]:bg-background"
        element :header, "cn-table-header"
        element :body, "cn-table-body"
        element :footer, "cn-table-footer"
        element :row, "cn-table-row transition-colors has-aria-expanded:bg-muted/50"
        element :head, "cn-table-head"
        element :cell, "cn-table-cell"
        element :caption, "cn-table-caption"
      end
    end
  end
end
