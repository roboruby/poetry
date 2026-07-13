# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # Re-expressed through the cn-* theme layer (N11). w-72 stays inline
      # per upstream's split (the caller-overridable width default); the
      # origin class binds through the tokens/aliases.css alias to popper's
      # generic var and stays inline as mechanism.
      class Style < Poetry::Core::Style
        # The panel's DISPLAY + header/body gap are THEME-owned (every N12
        # port ships its own flex-col gap-*; lyra/nova deliberately run
        # tighter at 2.5) - closed panels stay hidden regardless because
        # preflight's [hidden] rule is !important.
        element :content, "cn-popover-content z-50 w-72 " \
                          "origin-(--transform-origin) outline-hidden"

        # new-york-v4 additions (plain divs in source; poetry wires their
        # ids to the dialog's aria-labelledby/describedby).
        element :header, "cn-popover-header flex flex-col"
        element :title, "cn-popover-title"
        element :description, "cn-popover-description"
      end
    end
  end
end
