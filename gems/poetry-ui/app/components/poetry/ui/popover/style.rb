# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # The Popover dictionary - shadcn new-york-v4 popover.tsx,
      # source-validated 2026-07-02 (Popover). Class
      # strings are source-exact per part; the w-72 width is a class
      # default the caller overrides via class merge (demo: w-80). The
      # origin-(--radix-popover-content-transform-origin) class binds
      # through the tokens/aliases.css alias to popper's generic var.
      class Style < Poetry::Core::Style
        element :content, "z-50 w-72 origin-(--radix-popover-content-transform-origin) rounded-md border " \
                          "bg-popover p-4 text-popover-foreground shadow-md outline-hidden " \
                          "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
                          "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
                          "data-closed:animate-out data-closed:fade-out-0 " \
                          "data-closed:zoom-out-95 data-open:animate-in " \
                          "data-open:fade-in-0 data-open:zoom-in-95"

        # new-york-v4 additions (plain divs in source; poetry wires their
        # ids to the dialog's aria-labelledby/describedby).
        element :header, "flex flex-col gap-1 text-sm"
        element :title, "font-medium"
        element :description, "text-muted-foreground"
      end
    end
  end
end
