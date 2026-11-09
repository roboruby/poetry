# frozen_string_literal: true

module Poetry
  module Motion
    module Marquee
      # The marquee's classes; the loop and its pauses live in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "flex w-full flex-col gap-2"
        element :viewport, "flex min-h-0 flex-1 overflow-hidden"
        element :track, "flex shrink-0 items-center justify-around"
        element :pause, "self-end rounded-md border px-2 py-1 text-xs text-muted-foreground hover:bg-accent " \
                        "hover:text-accent-foreground focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                        "focus-visible:outline-none aria-pressed:bg-accent aria-pressed:text-accent-foreground"
      end
    end
  end
end
