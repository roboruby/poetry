# frozen_string_literal: true

module Poetry
  module Ui
    module NavigationMenu
      # shadcn NavigationMenu (base-vega), the viewport=false subset,
      # source-exact - the root emits data-viewport=false so the content's
      # group-data-[viewport=false] popup chrome applies. The :content
      # string keeps the motion/activation-direction classes inert (nothing
      # emits data-motion until the morphing viewport lands); the
      # :content_position element is the poetry ADAPTATION replacing the
      # Base UI Positioner (each panel sits under its relative item).
      class Style < Poetry::Core::Style
        base "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"

        element :list, "group flex flex-1 list-none items-center justify-center gap-0"
        element :item, "relative"

        element :trigger, "group/navigation-menu-trigger inline-flex h-9 w-max items-center " \
                          "justify-center rounded-md px-4 py-2 text-sm font-medium transition-all " \
                          "outline-none hover:bg-muted focus:bg-muted focus-visible:ring-3 " \
                          "focus-visible:ring-ring/50 focus-visible:outline-1 " \
                          "disabled:pointer-events-none disabled:opacity-50 " \
                          "data-popup-open:bg-muted/50 data-popup-open:hover:bg-muted " \
                          "data-open:bg-muted/50 data-open:hover:bg-muted data-open:focus:bg-muted"
        element :chevron, "relative top-px ml-1 size-3 transition duration-300 " \
                          "group-data-popup-open/navigation-menu-trigger:rotate-180 " \
                          "group-data-open/navigation-menu-trigger:rotate-180"

        # The activation-direction translate classes (the source's leading
        # four data-ending/starting-style:data-activation-direction=* slides)
        # are dropped: they belong to the morphing shared viewport (deferred)
        # and are malformed as standalone Tailwind variants anyway - they
        # compile to nothing. Restore them with the viewport milestone.
        element :content,
                "h-full w-auto p-2 pr-2.5 transition-[opacity,transform,translate] duration-[0.35s] " \
                "ease-[cubic-bezier(0.22,1,0.36,1)] " \
                "group-data-[viewport=false]/navigation-menu:rounded-md " \
                "group-data-[viewport=false]/navigation-menu:bg-popover " \
                "group-data-[viewport=false]/navigation-menu:text-popover-foreground " \
                "group-data-[viewport=false]/navigation-menu:shadow " \
                "group-data-[viewport=false]/navigation-menu:ring-1 " \
                "group-data-[viewport=false]/navigation-menu:ring-foreground/10 " \
                "group-data-[viewport=false]/navigation-menu:duration-300 " \
                "data-ending-style:opacity-0 data-starting-style:opacity-0 " \
                "data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 " \
                "data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 " \
                "data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in " \
                "data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out " \
                "**:data-[slot=navigation-menu-link]:focus:ring-0 " \
                "**:data-[slot=navigation-menu-link]:focus:outline-none " \
                "group-data-[viewport=false]/navigation-menu:data-open:animate-in " \
                "group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 " \
                "group-data-[viewport=false]/navigation-menu:data-open:zoom-in-95 " \
                "group-data-[viewport=false]/navigation-menu:data-closed:animate-out " \
                "group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0 " \
                "group-data-[viewport=false]/navigation-menu:data-closed:zoom-out-95"
        element :content_position, "absolute top-full left-0 isolate z-50 mt-1.5 w-max min-w-48"

        element :link, "flex items-center gap-1.5 rounded-md p-2 text-sm transition-all outline-none " \
                       "hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 " \
                       "focus-visible:outline-1 in-data-[slot=navigation-menu-content]:rounded-sm " \
                       "data-[active=true]:bg-muted/50 data-[active=true]:hover:bg-muted " \
                       "data-[active=true]:focus:bg-muted [&_svg:not([class*='size-'])]:size-4"
      end
    end
  end
end
