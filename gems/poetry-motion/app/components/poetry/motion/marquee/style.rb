# frozen_string_literal: true

module Poetry
  module Motion
    module Marquee
      # The marquee's classes; the loop and its pauses live in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "relative flex w-full overflow-hidden"
        element :track, "flex shrink-0 items-center justify-around"
        element :pause, "absolute end-2 bottom-2 rounded-md bg-background/80 px-2 py-1 text-xs text-foreground " \
                        "shadow-xs backdrop-blur focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                        "focus-visible:outline-none aria-pressed:bg-accent"
      end
    end
  end
end
