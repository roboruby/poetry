# frozen_string_literal: true

module Poetry
  module Ui
    module Drawer
      # Re-expressed through the cn-* theme layer (N11), still the
      # native-dialog swipe spine. The ENTIRE swipe mechanism stays inline
      # (transform vars, swipe-progress backdrop math, starting/ending
      # transforms, the direction margin geometry + closed-transform vars)
      # - a swapped theme can restyle surfaces but never break the gesture.
      # Margins stay dictionary-side ON BOTH content and directions so the
      # merger keeps collapsing m-0 against the side margins exactly as
      # before (the split-side conflict rule, applied by keeping the
      # conflict on the inline side this time). Corners/edges/surface ride
      # the theme. Deferred scope unchanged (snap points, nested stack).
      class Style < Poetry::Core::Style
        # open:flex, not flex: never defeat the UA's dialog:not([open])
        # display:none (the Dialog browser-pass lesson).
        # Scrim color + blur are theme-owned (W5 roster pass): each
        # themes/<name>.css carries backdrop:bg-* / backdrop-blur-* on
        # .cn-drawer-content. Only the swipe machinery (transition +
        # opacity calc) stays structural here.
        # No `relative`: the top layer discards it and the UA reasserts
        # `absolute`, pinning the drawer to the DOCUMENT edge (it scrolls
        # off-screen below the fold). The UA `:modal` rule keeps it
        # viewport-fixed so the direction auto-margins pin it to the viewport
        # edge; the swipe transform rides on top.
        element :content,
                "cn-drawer-content m-0 open:flex min-h-0 flex-col " \
                "outline-none select-none will-change-transform " \
                "transition-[transform,opacity] duration-450 ease-[cubic-bezier(0.22,1,0.36,1)] " \
                "transform-[translate3d(var(--translate-x,0px),var(--translate-y,0px),0)] " \
                "data-swiping:duration-0 " \
                "data-starting-style:transform-(--closed-transform) " \
                "data-ending-style:transform-(--closed-transform) " \
                "data-ending-style:duration-[calc(var(--drawer-swipe-strength,1)*400ms)] " \
                "backdrop:transition-opacity backdrop:duration-450 " \
                "backdrop:opacity-[calc(1-var(--drawer-swipe-progress,0))] " \
                "data-swiping:backdrop:transition-none"

        # The dismiss-direction geometry: top-layer edge margins + the
        # direction's closed transform, with the controller's positive
        # movement mapped onto the axis (negative directions invert it).
        # The corner/edge treatment rides cn-drawer-direction-*.
        # --drawer-inset (theme-owned; upstream's "floats the drawer from
        # the viewport edges", default 0px = flush) gaps every non-anchored
        # edge: the anchored side swaps its 0-margin for the inset, the
        # cross axis swaps its explicit size (w-full/h-full) for auto so
        # the UA's inset:0 over-constraint fills viewport-minus-margins
        # (identical to the full size at 0px), and the closed transform
        # travels the extra inset so the exit still clears the viewport.
        # rhea/mira/luma/maia ship --spacing(2), like their source styles.
        variant :direction, {
          down: "cn-drawer-direction-down mt-auto mb-(--drawer-inset,0px) mx-(--drawer-inset,0px) " \
                "h-auto w-auto max-w-none max-h-[calc(100dvh-6rem)] " \
                "[--closed-transform:translate3d(0,calc(100%+var(--drawer-inset,0px)+2px),0)] " \
                "[--translate-y:var(--drawer-swipe-movement-y,0px)]",
          up: "cn-drawer-direction-up mb-auto mt-(--drawer-inset,0px) mx-(--drawer-inset,0px) " \
              "h-auto w-auto max-w-none max-h-[calc(100dvh-6rem)] " \
              "[--closed-transform:translate3d(0,calc(-100%-var(--drawer-inset,0px)-2px),0)] " \
              "[--translate-y:calc(-1*var(--drawer-swipe-movement-y,0px))]",
          left: "cn-drawer-direction-left mr-auto ml-(--drawer-inset,0px) my-(--drawer-inset,0px) " \
                "h-auto max-h-none w-3/4 sm:max-w-sm " \
                "[--closed-transform:translate3d(calc(-100%-var(--drawer-inset,0px)-2px),0,0)] " \
                "[--translate-x:calc(-1*var(--drawer-swipe-movement-x,0px))]",
          right: "cn-drawer-direction-right ml-auto mr-(--drawer-inset,0px) my-(--drawer-inset,0px) " \
                 "h-auto max-h-none w-3/4 sm:max-w-sm " \
                 "[--closed-transform:translate3d(calc(100%+var(--drawer-inset,0px)+2px),0,0)] " \
                 "[--translate-x:var(--drawer-swipe-movement-x,0px)]"
        }

        # The grab pill (touch-none keeps the browser from stealing the
        # drag for scroll); the pill's look rides the theme rule.
        element :handle, "cn-drawer-swipe-handle relative z-10 mx-auto flex h-3 w-full shrink-0 " \
                         "cursor-grab touch-none items-center justify-center active:cursor-grabbing " \
                         "after:block after:shrink-0"

        element :header, "cn-drawer-header flex shrink-0 flex-col"
        element :footer, "cn-drawer-footer mt-auto flex shrink-0 flex-col"
        element :title, "cn-drawer-title"
        element :description, "cn-drawer-description"
        element :body, "cn-drawer-body flex min-h-0 flex-1 flex-col overflow-y-auto overscroll-contain"

        # The direction's edge classes for the <dialog> element (the Sheet
        # resolver pattern: variants render at the dictionary root, and the
        # Drawer's visual root is the :content element).
        def self.direction(value)
          resolver.variants.fetch(:direction).fetch(value.to_sym)
        end
      end
    end
  end
end
