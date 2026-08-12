# frozen_string_literal: true

module Poetry
  module Ui
    module NavigationMenu
      # Re-expressed through the cn-* theme layer (N11). The D3 morph
      # machinery stays ENTIRELY inline (positioner insets + size-var
      # transitions, panel adoption pins, activation-direction slides,
      # data-instant suppressors) - a swapped theme restyles the popup
      # surface, never the morph. The viewport=false chrome chain and the
      # trigger/link treatments ride the theme.
      class Style < Poetry::Core::Style
        base "cn-navigation-menu group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"

        element :list, "cn-navigation-menu-list group flex flex-1 list-none items-center justify-center"
        element :item, "relative"

        element :trigger, "cn-navigation-menu-trigger group/navigation-menu-trigger inline-flex h-9 " \
                          "w-max items-center justify-center outline-none " \
                          "disabled:pointer-events-none disabled:opacity-50"
        element :chevron, "cn-navigation-menu-trigger-icon relative top-px transition duration-300 " \
                          "group-data-popup-open/navigation-menu-trigger:rotate-180 " \
                          "group-data-open/navigation-menu-trigger:rotate-180"

        # The activation-direction slides stay inline (authored as VALID
        # Tailwind variants - upstream's own strings are malformed and
        # compile to nothing, the W4c compiled-CSS catch): content slides
        # in FROM the travel direction and out the other way.
        # h-full is the VIEWPORT-mode contract (the panel fills the
        # morphing popup box); inline panels size to their content - an
        # unscoped h-full clamps them to the 36px list item and the
        # popover chrome paints short of the rows.
        element :content,
                "cn-navigation-menu-content w-auto " \
                "group-data-[viewport=true]/navigation-menu:h-full " \
                "transition-[opacity,transform,translate] duration-[0.35s] " \
                "ease-[cubic-bezier(0.22,1,0.36,1)] " \
                "group-data-[viewport=false]/navigation-menu:duration-300 " \
                "data-ending-style:opacity-0 data-starting-style:opacity-0 " \
                "data-[activation-direction=right]:data-starting-style:translate-x-1/2 " \
                "data-[activation-direction=left]:data-starting-style:-translate-x-1/2 " \
                "data-[activation-direction=right]:data-ending-style:-translate-x-1/2 " \
                "data-[activation-direction=left]:data-ending-style:translate-x-1/2 " \
                "**:data-[slot=navigation-menu-link]:focus:ring-0 " \
                "**:data-[slot=navigation-menu-link]:focus:outline-none"
        element :content_position, "absolute top-full left-0 isolate z-50 mt-1.5 w-max min-w-48"

        # The morphing shared viewport (D3): the popper writes the positioner's
        # insets (CSS transitions them - the position morph); the popup pins
        # --popup-width/height old -> new so size transitions; panels stack
        # absolutely inside the viewport and size intrinsically. data-instant
        # (cold opens) suppresses both transitions for a frame.
        element :positioner, "absolute isolate z-50 w-(--positioner-width) h-(--positioner-height) " \
                             "transition-[top,left,right,bottom] duration-[0.35s] " \
                             "ease-[cubic-bezier(0.22,1,0.36,1)] data-instant:transition-none"
        element :popup, "cn-navigation-menu-popup relative h-(--popup-height) w-(--popup-width) " \
                        "overflow-hidden transition-[width,height] duration-[0.35s] " \
                        "ease-[cubic-bezier(0.22,1,0.36,1)] data-instant:transition-none"
        # The ACTIVE panel sits in flow - after the settle reset returns the
        # size vars to auto, IT is what sizes the popup (all-absolute panels
        # would collapse the auto popup to 0x0). Only an EXITING panel lifts
        # out of flow (data-ending-style rides the whole exit), overlaying
        # the incoming one while both are visible - the Base UI move, done
        # declaratively.
        element :viewport_shell, "relative overflow-hidden"
        element :viewport_panel, "w-max min-w-48 data-ending-style:absolute " \
                                 "data-ending-style:top-0 data-ending-style:left-0"

        element :link, "cn-navigation-menu-link flex items-center outline-none"
      end
    end
  end
end
