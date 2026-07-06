# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # Re-expressed through the cn-* theme layer (N11). w-72 stays inline
      # per upstream's split (the caller-overridable width default); the
      # origin class binds through the tokens/aliases.css alias to popper's
      # generic var and stays inline as mechanism.
      class Style < Poetry::Core::Style
        element :content, "cn-popover-content z-50 w-72 " \
                          "origin-(--radix-popover-content-transform-origin) outline-hidden"

        # new-york-v4 additions (plain divs in source; poetry wires their
        # ids to the dialog's aria-labelledby/describedby).
        element :header, "cn-popover-header flex flex-col"
        element :title, "cn-popover-title"
        element :description, "cn-popover-description"
      end
    end
  end
end
