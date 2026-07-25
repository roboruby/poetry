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
        # No `relative`: a modal <dialog> lives in the top layer, where the
        # browser drops a `position: relative` back to the UA `absolute` and
        # pins the panel to the DOCUMENT origin (it then scrolls off-screen
        # when opened below the fold). Letting position fall through to the
        # UA `:modal` rule keeps it viewport-fixed and centered.
        element :content, "cn-dialog-content m-auto open:grid"

        element :header, "cn-dialog-header flex flex-col"
        element :title, "cn-dialog-title"
        element :description, "cn-dialog-description"
        element :footer, "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
        element :close, "cn-dialog-close"
      end
    end
  end
end
