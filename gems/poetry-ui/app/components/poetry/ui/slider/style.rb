# frozen_string_literal: true

module Poetry
  module Ui
    module Slider
      # The Slider dictionary - shadcn new-york-v4 slider.tsx,
      # source-validated 2026-07-03 (Slider). Root /
      # track / range / thumb strings are source-exact, including the
      # RECORDED golden-diff exception: the thumb keeps the source ring-4
      # swelling focus ring (hover:ring-4 focus-visible:ring-4 ring-ring/50
      # + outline-hidden), NOT the suite 3px ring - on a 16px circular
      # thumb the swelling ring is the shadcn design and doubles as the
      # hover affordance. bg-white is LITERAL in source (the thumb stays
      # white in dark mode - deliberate).
      #
      # Poetry's geometry additions replace Radix's inline left/right
      # styles with two CSS custom properties (--slider-start/--slider-end,
      # server-rendered, controller-rewritten via CSSOM) consumed by static
      # calc() rules - every class stays verifiable against the compiled
      # build. Logical properties (start-*) make horizontal RTL flip for
      # free (the controller computes percents value-wise; inline-start IS
      # the value origin in both directions).
      class Style < Poetry::Core::Style
        base "relative flex w-full touch-none items-center select-none " \
             "data-[disabled]:opacity-50 data-[orientation=vertical]:h-full " \
             "data-[orientation=vertical]:min-h-44 data-[orientation=vertical]:w-auto " \
             "data-[orientation=vertical]:flex-col"

        element :track, "relative grow overflow-hidden rounded-full bg-muted " \
                        "data-[orientation=horizontal]:h-1.5 data-[orientation=horizontal]:w-full " \
                        "data-[orientation=vertical]:h-full data-[orientation=vertical]:w-1.5"

        # Source string + the geometry rules: horizontal spans
        # [--slider-start, --slider-end] along the inline axis; vertical
        # grows BOTTOM-up (APG).
        element :range, "absolute bg-primary data-[orientation=horizontal]:h-full " \
                        "data-[orientation=vertical]:w-full " \
                        "data-[orientation=horizontal]:start-(--slider-start) " \
                        "data-[orientation=horizontal]:end-[calc(100%-var(--slider-end))] " \
                        "data-[orientation=vertical]:bottom-(--slider-start) " \
                        "data-[orientation=vertical]:top-[calc(100%-var(--slider-end))]"

        element :thumb, "block size-4 shrink-0 rounded-full border border-primary bg-white shadow-sm " \
                        "ring-ring/50 transition-[color,box-shadow] hover:ring-4 focus-visible:ring-4 " \
                        "focus-visible:outline-hidden disabled:pointer-events-none disabled:opacity-50"

        # The per-thumb positioning anchor (Radix wraps each thumb in an
        # absolutely positioned span - poetry's version rides the geometry
        # vars; calc(P% - 0.5rem) centers the 1rem thumb at P%).
        element :anchor, "absolute data-[orientation=horizontal]:top-1/2 " \
                         "data-[orientation=horizontal]:-translate-y-1/2 " \
                         "data-[orientation=vertical]:left-1/2 data-[orientation=vertical]:-translate-x-1/2"

        # The low thumb (range mode) anchors at --slider-start...
        element :anchor_start, "data-[orientation=horizontal]:start-[calc(var(--slider-start)-0.5rem)] " \
                               "data-[orientation=vertical]:bottom-[calc(var(--slider-start)-0.5rem)]"

        # ...the high (or single) thumb at --slider-end.
        element :anchor_end, "data-[orientation=horizontal]:start-[calc(var(--slider-end)-0.5rem)] " \
                             "data-[orientation=vertical]:bottom-[calc(var(--slider-end)-0.5rem)]"
      end
    end
  end
end
