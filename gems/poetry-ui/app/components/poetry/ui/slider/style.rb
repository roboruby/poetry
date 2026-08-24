# frozen_string_literal: true

module Poetry
  module Ui
    module Slider
      # Style dictionary for the Slider family. The geometry spine stays
      # ENTIRELY inline: the --slider-start/--slider-end custom properties
      # (server-rendered, controller-rewritten via CSSOM) and every calc()
      # consumer on :range and the :anchor trio - a swapped theme can
      # restyle the surfaces but can never break the math. The thumb keeps
      # the ring-4 swelling focus ring, and bg-white is literal (the thumb
      # stays white in dark mode).
      class Style < Poetry::Core::Style
        base "cn-slider relative flex w-full touch-none items-center select-none " \
             "data-[disabled]:opacity-50 data-[orientation=vertical]:h-full " \
             "data-[orientation=vertical]:w-auto data-[orientation=vertical]:flex-col"

        element :track, "cn-slider-track relative grow overflow-hidden"

        # The geometry rules: horizontal spans [--slider-start,
        # --slider-end] along the inline axis; vertical grows BOTTOM-up
        # (APG). Logical properties (start-*) flip RTL for free.
        element :range, "cn-slider-range absolute data-[orientation=horizontal]:h-full " \
                        "data-[orientation=vertical]:w-full " \
                        "data-[orientation=horizontal]:start-(--slider-start) " \
                        "data-[orientation=horizontal]:end-[calc(100%-var(--slider-end))] " \
                        "data-[orientation=vertical]:bottom-(--slider-start) " \
                        "data-[orientation=vertical]:top-[calc(100%-var(--slider-end))]"

        element :thumb, "cn-slider-thumb block shrink-0 " \
                        "disabled:pointer-events-none disabled:opacity-50"

        # The per-thumb positioning anchor - an absolutely positioned span
        # riding the geometry vars; calc(P% - 0.5rem) centers the 1rem
        # thumb at P%.
        element :anchor, "absolute data-[orientation=horizontal]:top-1/2 " \
                         "data-[orientation=horizontal]:-translate-y-1/2 " \
                         "data-[orientation=vertical]:left-1/2 data-[orientation=vertical]:-translate-x-1/2"

        # The low thumb (range mode) anchors at --slider-start...
        element :anchor_start, "data-[orientation=horizontal]:start-[calc(var(--slider-start)-0.5rem)] " \
                               "data-[orientation=vertical]:bottom-[calc(var(--slider-start)-0.5rem)]"

        # ...the high (or single) thumb at --slider-end.
        element :anchor_end, "data-[orientation=horizontal]:start-[calc(var(--slider-end)-0.5rem)] " \
                             "data-[orientation=vertical]:bottom-[calc(var(--slider-end)-0.5rem)]"

        # Middle thumbs (N-thumb sliders) carry their own inline
        # --slider-mid var - two shared vars cannot place N positions.
        element :anchor_mid, "data-[orientation=horizontal]:start-[calc(var(--slider-mid)-0.5rem)] " \
                             "data-[orientation=vertical]:bottom-[calc(var(--slider-mid)-0.5rem)]"
      end
    end
  end
end
