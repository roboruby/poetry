# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # The Tooltip dictionary - shadcn new-york-v4 tooltip.tsx,
      # source-validated 2026-07-02 (Tooltip). The
      # inverse scheme (bg-foreground/text-background) IS the treatment -
      # the only trio member not on popover tokens. Note animate-in is
      # UNGATED (source-exact): the open animation classes are
      # unconditional, only the exit chain is data-state-gated. The origin
      # class binds through the tokens/aliases.css alias to popper's
      # generic var.
      class Style < Poetry::Core::Style
        element :content, "z-50 w-fit origin-(--radix-tooltip-content-transform-origin) animate-in " \
                          "rounded-md bg-foreground px-3 py-1.5 text-xs text-balance text-background " \
                          "fade-in-0 zoom-in-95 data-[side=bottom]:slide-in-from-top-2 " \
                          "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 " \
                          "data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out " \
                          "data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95"

        # The built-in arrow's visual classes (source-exact, riding an
        # inner span; the outer data-slot=tooltip-arrow box is popper's
        # ARROW target - positioned + rotated by the controller).
        element :arrow, "z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] " \
                        "bg-foreground fill-foreground"
      end
    end
  end
end
