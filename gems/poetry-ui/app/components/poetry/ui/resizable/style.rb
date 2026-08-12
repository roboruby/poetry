# frozen_string_literal: true

module Poetry
  module Ui
    module Resizable
      # shadcn Resizable (base-vega), source-exact - except the GROUP's
      # layout key: upstream styles it off aria-orientation, which ARIA
      # does not permit on a plain group container (an axe aria-allowed-attr
      # violation upstream ships) - poetry keys the same classes off
      # data-orientation, its established layout token. The handle keeps
      # the source's aria-[orientation] selectors (valid on role=separator).
      class Style < Poetry::Core::Style
        base "flex h-full w-full data-[orientation=vertical]:flex-col"

        element :panel, "overflow-hidden"

        element :handle, "relative flex w-px items-center justify-center bg-border " \
                         "ring-offset-background after:absolute after:inset-y-0 after:left-1/2 " \
                         "after:w-1 after:-translate-x-1/2 focus-visible:ring-1 focus-visible:ring-ring " \
                         "focus-visible:outline-hidden aria-[orientation=horizontal]:h-px " \
                         "aria-[orientation=horizontal]:w-full aria-[orientation=horizontal]:after:left-0 " \
                         "aria-[orientation=horizontal]:after:h-1 aria-[orientation=horizontal]:after:w-full " \
                         "aria-[orientation=horizontal]:after:translate-x-0 " \
                         "aria-[orientation=horizontal]:after:-translate-y-1/2 " \
                         "[&[aria-orientation=horizontal]>div]:rotate-90"
        element :grip, "cn-resizable-handle-icon z-10 flex shrink-0"
      end
    end
  end
end
