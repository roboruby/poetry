# frozen_string_literal: true

module Poetry
  module Ui
    module Sidebar
      # Re-expressed through the cn-* theme layer (N11). The collapse /
      # rail / inset geometry chains (width vars, offcanvas math, icon-mode
      # size! pads, peer-size action tops) stay ENTIRELY inline - the
      # machinery a swapped theme must never break; surfaces, tints, and
      # type ride the theme. The mobile <dialog> follows the Drawer rule:
      # m-0 and the side margins BOTH stay inline so the merger keeps
      # collapsing them. Upstream's size names (cn-sidebar-menu-button-
      # size-*) are kept verbatim.
      class Style < Poetry::Core::Style
        base ""

        # The provider wrapper carries the width custom properties.
        element :wrapper, "flex min-h-svh w-full has-data-[variant=inset]:bg-sidebar"

        # The peer group (the desktop shell; below md the mobile <dialog>
        # takes over - W5b).
        element :peer, "group peer hidden text-sidebar-foreground md:block"

        # The mobile sheet (W5b), open:flex not flex (the Dialog lesson).
        element :mobile, "cn-sidebar-mobile relative m-0 open:flex h-full max-h-none " \
                         "w-(--sidebar-width) max-w-none flex-col md:hidden"
        element :mobile_left, "cn-sidebar-mobile-left mr-auto"
        element :mobile_right, "cn-sidebar-mobile-right ml-auto"
        element :mobile_inner, "flex h-full w-full flex-col"

        # The mobile side's edge classes for the <dialog>.
        def self.mobile_side(value)
          resolver.render(:"mobile_#{value}")
        end

        # The desktop gap that pushes the inset over.
        element :gap, "relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 " \
                      "ease-linear group-data-[collapsible=offcanvas]:w-0 group-data-[side=right]:rotate-180 " \
                      "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
        element :gap_inset, "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]"

        element :container,
                "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] " \
                "duration-200 ease-linear data-[side=left]:left-0 " \
                "data-[side=left]:group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)] " \
                "data-[side=right]:right-0 " \
                "data-[side=right]:group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)] " \
                "md:flex group-data-[collapsible=icon]:w-(--sidebar-width-icon) " \
                "group-data-[side=left]:border-r group-data-[side=right]:border-l"
        element :container_inset,
                "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]"

        element :inner, "cn-sidebar-inner flex size-full flex-col"

        element :inset,
                "relative flex w-full flex-1 flex-col bg-background " \
                "md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 " \
                "md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm " \
                "md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2"

        # The rail (desktop-only click strip).
        element :rail,
                "absolute inset-y-0 z-20 hidden w-4 transition-all ease-linear " \
                "group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute after:inset-y-0 " \
                "after:start-1/2 after:w-[2px] hover:after:bg-sidebar-border sm:flex " \
                "group-data-[collapsible=offcanvas]:translate-x-0 " \
                "group-data-[collapsible=offcanvas]:after:left-full hover:group-data-[collapsible=offcanvas]:bg-sidebar"

        element :header, "cn-sidebar-header flex flex-col"
        element :footer, "cn-sidebar-footer flex flex-col"
        element :separator, "cn-sidebar-separator w-auto"
        element :content, "cn-sidebar-content no-scrollbar flex min-h-0 flex-1 flex-col overflow-auto " \
                          "group-data-[collapsible=icon]:overflow-hidden"

        element :group, "cn-sidebar-group relative flex w-full min-w-0 flex-col"
        element :group_label, "cn-sidebar-group-label flex shrink-0 items-center outline-hidden " \
                              "transition-[margin,opacity] duration-200 ease-linear " \
                              "group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0 " \
                              "[&>svg]:shrink-0"
        element :group_content, "cn-sidebar-group-content w-full"

        element :menu, "cn-sidebar-menu flex w-full min-w-0 flex-col"
        element :menu_item, "group/menu-item relative"
        element :menu_button,
                "cn-sidebar-menu-button peer/menu-button flex w-full items-center overflow-hidden " \
                "text-left outline-hidden transition-[width,height,padding] " \
                "group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:p-2! " \
                "disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none " \
                "aria-disabled:opacity-50 [&_svg]:shrink-0 [&>span:last-child]:truncate"
        element :menu_button_default, "cn-sidebar-menu-button-size-default"

        # The item-corner action + badge (W5b commit 3) - positions and
        # reveal machinery inline, tints/type themed.
        element :menu_action,
                "cn-sidebar-menu-action absolute top-1.5 right-1 flex aspect-square items-center " \
                "justify-center outline-hidden transition-transform " \
                "group-data-[collapsible=icon]:hidden " \
                "peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 " \
                "peer-data-[size=sm]/menu-button:top-1 after:absolute after:-inset-2 " \
                "md:after:hidden [&>svg]:shrink-0"
        element :menu_action_hover,
                "group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 " \
                "peer-data-active/menu-button:text-sidebar-accent-foreground aria-expanded:opacity-100 " \
                "md:opacity-0"
        element :menu_badge,
                "cn-sidebar-menu-badge pointer-events-none absolute right-1 flex items-center " \
                "justify-center select-none group-data-[collapsible=icon]:hidden " \
                "peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 " \
                "peer-data-[size=sm]/menu-button:top-1"
        element :menu_button_sm, "cn-sidebar-menu-button-size-sm"
        element :menu_button_lg, "cn-sidebar-menu-button-size-lg group-data-[collapsible=icon]:p-0!"

        element :menu_sub, "cn-sidebar-menu-sub mx-3.5 flex min-w-0 translate-x-px flex-col " \
                           "group-data-[collapsible=icon]:hidden"
        element :menu_sub_item, "relative"
        element :menu_sub_button, "cn-sidebar-menu-sub-button flex min-w-0 -translate-x-px items-center " \
                                  "overflow-hidden outline-hidden disabled:pointer-events-none " \
                                  "disabled:opacity-50 aria-disabled:pointer-events-none " \
                                  "aria-disabled:opacity-50 [&>svg]:shrink-0 [&>span:last-child]:truncate"

        def self.menu_button_size(value)
          css(:"menu_button_#{value}")
        end
      end
    end
  end
end
