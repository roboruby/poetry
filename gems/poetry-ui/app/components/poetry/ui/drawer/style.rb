# frozen_string_literal: true

module Poetry
  module Ui
    module Drawer
      # The Drawer dictionary - shadcn drawer (base-vega) adapted to the
      # native-dialog spine, the same move the Sheet port made: the div
      # Overlay becomes ::backdrop (which inherits the swipe vars from the
      # dialog, its originating element), fixed/inset positioning becomes
      # top-layer margins, and the Portal/Viewport wrappers collapse into
      # the <dialog>. Every swipe var carries a fallback so the calc chains
      # resolve before the controller ever writes (no inline style needed).
      #
      # Deliberately NOT ported (deferred with their machinery, W3b scope):
      # the snap-point sizing/offset terms, the nested-drawer stack lines
      # (--nested-drawers/--stack-*, incl. the scale() transform term), and
      # the bleed pseudo-element. The title's cn-font-heading drops like
      # every prior port (the cn-* theme layer is its own milestone).
      class Style < Poetry::Core::Style
        # open:flex, not flex: never defeat the UA's dialog:not([open])
        # display:none (the Dialog browser-pass lesson).
        element :content,
                "relative m-0 open:flex min-h-0 flex-col bg-popover text-sm text-popover-foreground " \
                "shadow-lg outline-none select-none will-change-transform " \
                "transition-[transform,opacity] duration-450 ease-[cubic-bezier(0.22,1,0.36,1)] " \
                "transform-[translate3d(var(--translate-x,0px),var(--translate-y,0px),0)] " \
                "data-swiping:duration-0 " \
                "data-starting-style:transform-(--closed-transform) " \
                "data-ending-style:transform-(--closed-transform) " \
                "data-ending-style:duration-[calc(var(--drawer-swipe-strength,1)*400ms)] " \
                "backdrop:bg-black/10 backdrop:transition-opacity backdrop:duration-450 " \
                "backdrop:opacity-[calc(1-var(--drawer-swipe-progress,0))] " \
                "data-swiping:backdrop:transition-none " \
                "supports-backdrop-filter:backdrop:backdrop-blur-xs"

        # The dismiss-direction chrome: top-layer edge margins + the
        # direction's closed transform, with the controller's positive
        # movement mapped onto the axis (negative directions invert it).
        variant :direction, {
          down: "mt-auto mb-0 h-auto w-full max-w-none max-h-[calc(100dvh-6rem)] rounded-t-xl border-t " \
                "[--closed-transform:translate3d(0,calc(100%+2px),0)] " \
                "[--translate-y:var(--drawer-swipe-movement-y,0px)]",
          up: "mb-auto mt-0 h-auto w-full max-w-none max-h-[calc(100dvh-6rem)] rounded-b-xl border-b " \
              "[--closed-transform:translate3d(0,calc(-100%-2px),0)] " \
              "[--translate-y:calc(-1*var(--drawer-swipe-movement-y,0px))]",
          left: "mr-auto ml-0 h-full max-h-none w-3/4 rounded-r-xl border-r sm:max-w-sm " \
                "[--closed-transform:translate3d(calc(-100%-2px),0,0)] " \
                "[--translate-x:calc(-1*var(--drawer-swipe-movement-x,0px))]",
          right: "ml-auto mr-0 h-full max-h-none w-3/4 rounded-l-xl border-l sm:max-w-sm " \
                 "[--closed-transform:translate3d(calc(100%+2px),0,0)] " \
                 "[--translate-x:var(--drawer-swipe-movement-x,0px)]"
        }

        # The grab pill (trimmed to the y-axis form the handle is for;
        # touch-none keeps the browser from stealing the drag for scroll).
        element :handle, "relative z-10 mx-auto flex h-3 w-full shrink-0 cursor-grab touch-none " \
                         "items-center justify-center active:cursor-grabbing " \
                         "after:block after:h-1.5 after:w-[100px] after:shrink-0 after:rounded-full " \
                         "after:bg-muted"

        element :header, "flex shrink-0 flex-col gap-0.5 p-4 pb-0 text-center md:gap-1.5 md:text-left"
        element :footer, "mt-auto flex shrink-0 flex-col gap-2 p-4 pt-0"
        element :title, "font-medium text-foreground"
        element :description, "text-sm text-balance text-muted-foreground"
        element :body, "flex min-h-0 flex-1 flex-col overflow-y-auto overscroll-contain p-4"

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
