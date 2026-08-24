# frozen_string_literal: true

module Poetry
  module Ui
    module Carousel
      # Style dictionary for the Carousel family, on native scroll-snap:
      # the content wrapper is the REAL scroll container
      # (overflow + snap + hidden scrollbar) rather than an
      # overflow-hidden + transform track; the gutter idiom (-ml-4 track,
      # pl-4 items) and the control positions are kept as designed.
      class Style < Poetry::Core::Style
        base "relative"

        element :content, "overflow-auto [scrollbar-width:none] snap-mandatory"
        element :content_horizontal, "snap-x"
        element :content_vertical, "snap-y"

        element :track, "flex"
        element :track_horizontal, "-ml-4"
        element :track_vertical, "-mt-4 flex-col"

        element :item, "min-w-0 shrink-0 grow-0 basis-full snap-start"
        # The negative scroll-margin cancels the gutter from the snap area:
        # native snap-start (and scrollIntoView) aligns the item's BORDER
        # box, which includes the pl-4 gutter - without it, every slide
        # after the first snaps 16px short and its trailing edge clips.
        # An engine that translates by measured offsets never has this seam.
        element :item_horizontal, "pl-4 -scroll-ml-4"
        element :item_vertical, "pt-4 -scroll-mt-4"

        element :control, "absolute touch-manipulation"
        element :control_previous_horizontal, "inset-y-0 -left-12 my-auto"
        element :control_previous_vertical, "-top-12 left-1/2 -translate-x-1/2 rotate-90"
        element :control_next_horizontal, "inset-y-0 -right-12 my-auto"
        element :control_next_vertical, "-bottom-12 left-1/2 -translate-x-1/2 rotate-90"
      end
    end
  end
end
