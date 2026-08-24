# frozen_string_literal: true

module Poetry
  module Ui
    module Resizable
      # Style dictionary for the Resizable family. The GROUP's layout keys
      # off data-orientation - aria-orientation is not permitted on a
      # plain group container (an axe aria-allowed-attr violation). The
      # handle keeps aria-[orientation] selectors (valid on
      # role=separator).
      class Style < Poetry::Core::Style
        base "flex h-full w-full data-[orientation=vertical]:flex-col"

        element :panel, "overflow-hidden"

        element :handle, "relative flex w-px touch-none items-center justify-center bg-border " \
                         "cursor-col-resize aria-[orientation=horizontal]:cursor-row-resize " \
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
