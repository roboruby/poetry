# frozen_string_literal: true

module Poetry
  module Ui
    module InputGroup
      # Re-expressed through the cn-* theme layer. The structural
      # reflow chain (block addons force h-auto/flex-col) stays inline -
      # it is layout mechanism; the chrome (border, focus-within ring,
      # invalid ring, paddings) rides themes/default.css. Upstream's addon
      # click-to-focus handler remains skipped (static port).
      class Style < Poetry::Core::Style
        base "cn-input-group group/input-group relative flex w-full min-w-0 items-center outline-none " \
             "has-[>[data-align=block-end]]:h-auto has-[>[data-align=block-end]]:flex-col " \
             "has-[>[data-align=block-start]]:h-auto has-[>[data-align=block-start]]:flex-col " \
             "has-[>textarea]:h-auto"

        # The addon: shared chrome + one align axis (inline = in the row,
        # block = its own full-width row).
        element :addon, "cn-input-group-addon flex cursor-text items-center justify-center select-none"
        element :addon_inline_start, "cn-input-group-addon-align-inline-start order-first"
        element :addon_inline_end, "cn-input-group-addon-align-inline-end order-last"
        element :addon_block_start, "cn-input-group-addon-align-block-start order-first w-full justify-start"
        element :addon_block_end, "cn-input-group-addon-align-block-end order-last w-full justify-start"

        element :text, "cn-input-group-text flex items-center [&_svg]:pointer-events-none"

        # The borderless control overrides (merged over Input/Textarea).
        element :control_input, "cn-input-group-input flex-1"
        element :control_textarea, "cn-input-group-textarea flex-1 resize-none"

        # The tiny in-group Button sizes (merged over the ghost Button).
        element :button, "cn-input-group-button flex items-center shadow-none"
        element :button_xs, "cn-input-group-button-size-xs"
        element :button_sm, "cn-input-group-button-size-sm"
        element :button_icon_xs, "cn-input-group-button-size-icon-xs"
        element :button_icon_sm, "cn-input-group-button-size-icon-sm"
      end
    end
  end
end
