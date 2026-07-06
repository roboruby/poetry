# frozen_string_literal: true

module Poetry
  module Ui
    module Breadcrumb
      # Re-expressed through the cn-* theme layer (N11). The separator
      # chevron's cn-rtl-flip lands with the W4 consumer-utility batch.
      # No cn-breadcrumb root name: the root's poetry surface is empty and
      # empty theme rules don't survive compilation (data-slot remains the
      # restyle hook).
      class Style < Poetry::Core::Style
        base ""

        element :list, "cn-breadcrumb-list flex flex-wrap items-center wrap-break-word"
        element :item, "cn-breadcrumb-item inline-flex items-center"
        element :link, "cn-breadcrumb-link"
        element :page, "cn-breadcrumb-page"
        element :separator, "cn-breadcrumb-separator"
        element :ellipsis, "cn-breadcrumb-ellipsis flex items-center justify-center"
      end
    end
  end
end
