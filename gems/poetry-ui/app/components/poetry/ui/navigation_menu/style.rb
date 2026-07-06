# frozen_string_literal: true

module Poetry
  module Ui
    module NavigationMenu
      # shadcn NavigationMenu (base-vega), source-exact. Two modes: the root
      # emits data-viewport=false (per-item popups - the content's
      # group-data-[viewport=false] chrome) or true (D3: the morphing shared
      # positioner > popup > viewport). :content_position is the per-item
      # placement; :positioner/:popup/:viewport_shell/:viewport_panel are the
      # shared-shell tier.
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

        # The activation-direction slides landed with the viewport milestone
        # (D3) - authored as VALID Tailwind variants (upstream's own strings
        # are malformed and compile to nothing, the W4c compiled-CSS catch):
        # content slides in FROM the travel direction and out the other way.
        # They replace the inert Radix data-[motion...] set W4c carried.
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
                "data-[activation-direction=right]:data-starting-style:translate-x-1/2 " \
                "data-[activation-direction=left]:data-starting-style:-translate-x-1/2 " \
                "data-[activation-direction=right]:data-ending-style:-translate-x-1/2 " \
                "data-[activation-direction=left]:data-ending-style:translate-x-1/2 " \
                "**:data-[slot=navigation-menu-link]:focus:ring-0 " \
                "**:data-[slot=navigation-menu-link]:focus:outline-none " \
                "group-data-[viewport=false]/navigation-menu:data-open:animate-in " \
                "group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 " \
                "group-data-[viewport=false]/navigation-menu:data-open:zoom-in-95 " \
                "group-data-[viewport=false]/navigation-menu:data-closed:animate-out " \
                "group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0 " \
                "group-data-[viewport=false]/navigation-menu:data-closed:zoom-out-95"
        element :content_position, "absolute top-full left-0 isolate z-50 mt-1.5 w-max min-w-48"

        # The morphing shared viewport (D3): the popper writes the positioner's
        # insets (CSS transitions them - the position morph); the popup pins
        # --popup-width/height old -> new so size transitions; panels stack
        # absolutely inside the viewport and size intrinsically. data-instant
        # (cold opens) suppresses both transitions for a frame.
        element :positioner, "absolute isolate z-50 w-(--positioner-width) h-(--positioner-height) " \
                             "transition-[top,left,right,bottom] duration-[0.35s] " \
                             "ease-[cubic-bezier(0.22,1,0.36,1)] data-instant:transition-none"
        element :popup, "relative h-(--popup-height) w-(--popup-width) overflow-hidden rounded-md " \
                        "bg-popover text-popover-foreground shadow ring-1 ring-foreground/10 " \
                        "transition-[width,height] duration-[0.35s] ease-[cubic-bezier(0.22,1,0.36,1)] " \
                        "data-instant:transition-none"
        # The ACTIVE panel sits in flow - after the settle reset returns the
        # size vars to auto, IT is what sizes the popup (all-absolute panels
        # would collapse the auto popup to 0x0). Only an EXITING panel lifts
        # out of flow (data-ending-style rides the whole exit), overlaying
        # the incoming one while both are visible - the Base UI move, done
        # declaratively.
        element :viewport_shell, "relative overflow-hidden"
        element :viewport_panel, "w-max min-w-48 data-ending-style:absolute " \
                                 "data-ending-style:top-0 data-ending-style:left-0"

        element :link, "flex items-center gap-1.5 rounded-md p-2 text-sm transition-all outline-none " \
                       "hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 " \
                       "focus-visible:outline-1 in-data-[slot=navigation-menu-content]:rounded-sm " \
                       "data-[active=true]:bg-muted/50 data-[active=true]:hover:bg-muted " \
                       "data-[active=true]:focus:bg-muted [&_svg:not([class*='size-'])]:size-4"
      end
    end
  end
end
