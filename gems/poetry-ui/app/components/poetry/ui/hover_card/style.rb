# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # The HoverCard dictionary - shadcn new-york-v4 hover-card.tsx,
      # source-validated 2026-07-02 (HoverCard). One
      # element: the preview panel on the popover token scheme (NOT
      # Tooltip's inverse), w-64 default the caller overrides via
      # content_class (demo: w-80). The origin class binds through the
      # tokens/aliases.css alias to popper's generic var - the trio's
      # third and final alias.
      class Style < Poetry::Core::Style
        element :content, "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-md " \
                          "border bg-popover p-4 text-popover-foreground shadow-md outline-hidden " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-closed:animate-out data-closed:fade-out-0 " \
                          "data-closed:zoom-out-95 data-open:animate-in " \
                          "data-open:fade-in-0 data-open:zoom-in-95"
      end
    end
  end
end
