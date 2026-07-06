# frozen_string_literal: true

module Poetry
  module Ui
    module Dialog
      # The root is a non-visual wrapper; the visual surface is the native
      # <dialog> element (the :content element), centered by the top layer.
      # Re-expressed through the cn-* theme layer (N11): the panel chrome,
      # backdrop tint, and enter animation ride themes/default.css; the
      # native-dialog mechanisms stay inline.
      class Style < Poetry::Core::Style
        # open:grid, NOT grid: a bare display class would defeat the UA's
        # dialog:not([open]) { display: none } and render the dialog inline
        # while closed (caught by the 2026-07-01 browser pass - invisible
        # to jsdom, which has no UA stylesheet).
        element :content, "cn-dialog-content relative m-auto open:grid"

        element :header, "cn-dialog-header flex flex-col"
        element :title, "cn-dialog-title"
        element :description, "cn-dialog-description"
        element :footer, "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
        element :close, "cn-dialog-close"
      end
    end
  end
end
