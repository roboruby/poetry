# frozen_string_literal: true

module Poetry
  module Ui
    module Sidebar
      # shadcn Sidebar (base-vega), the desktop-complete subset, source-exact.
      # The React SidebarProvider's isMobile branch (render inside a Sheet)
      # is deferred (W5b) - this ports the wrapper + the desktop peer shell
      # (gap / container / inner) and all the content parts. The collapse is
      # pure CSS off data-state (poetry--core--sidebar flips the attribute).
      class Style < Poetry::Core::Style
        base ""

        # The provider wrapper carries the width custom properties. Upstream
        # names it group/sidebar-wrapper; that marker (and group/menu-button,
        # group/menu-sub-item) stays dropped - their only consumers live at
        # BLOCK level upstream, and the compiled-CSS gate flags markers
        # nothing in-gem consumes. peer/menu-button and group/menu-item
        # returned at W5b commit 3 WITH their consumers (menu-action/badge).
        element :wrapper, "flex min-h-svh w-full has-data-[variant=inset]:bg-sidebar"

        # The peer group (the desktop shell; below md the mobile <dialog>
        # takes over - W5b).
        element :peer, "group peer hidden text-sidebar-foreground md:block"

        # The mobile sheet (W5b): the Sheet's presence-animated panel
        # skinned as the sidebar - w-(--sidebar-width) at the 18rem mobile
        # width, p-0, bg-sidebar, no close button (dismissal = backdrop /
        # Esc), md:hidden keeps it out of the desktop layout wholesale.
        # open:flex not flex (the Dialog browser-pass lesson).
        element :mobile, "relative m-0 open:flex h-full max-h-none w-(--sidebar-width) max-w-none flex-col " \
                         "bg-sidebar p-0 text-sidebar-foreground shadow-lg transition ease-in-out " \
                         "data-open:animate-in data-open:duration-500 " \
                         "data-closed:animate-out data-closed:duration-300 " \
                         "backdrop:bg-black/50 md:hidden"
        element :mobile_left, "mr-auto border-r data-open:slide-in-from-left data-closed:slide-out-to-left"
        element :mobile_right, "ml-auto border-l data-open:slide-in-from-right data-closed:slide-out-to-right"
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

        element :inner, "flex size-full flex-col bg-sidebar group-data-[variant=floating]:rounded-lg " \
                        "group-data-[variant=floating]:shadow-sm group-data-[variant=floating]:ring-1 " \
                        "group-data-[variant=floating]:ring-sidebar-border"

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

        element :header, "flex flex-col gap-2 p-2"
        element :footer, "flex flex-col gap-2 p-2"
        element :separator, "mx-2 w-auto bg-sidebar-border"
        element :content, "no-scrollbar flex min-h-0 flex-1 flex-col gap-2 overflow-auto " \
                          "group-data-[collapsible=icon]:overflow-hidden"

        element :group, "relative flex w-full min-w-0 flex-col p-2"
        element :group_label, "flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium " \
                              "text-sidebar-foreground/70 ring-sidebar-ring outline-hidden " \
                              "transition-[margin,opacity] duration-200 ease-linear " \
                              "group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0 " \
                              "focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0"
        element :group_content, "w-full text-sm"

        element :menu, "flex w-full min-w-0 flex-col gap-1"
        element :menu_item, "group/menu-item relative"
        element :menu_button,
                "peer/menu-button flex w-full items-center gap-2 overflow-hidden " \
                "group-has-data-[sidebar=menu-action]/menu-item:pr-8 " \
                "rounded-md p-2 text-left text-sm ring-sidebar-ring outline-hidden " \
                "transition-[width,height,padding] group-data-[collapsible=icon]:size-8! " \
                "group-data-[collapsible=icon]:p-2! hover:bg-sidebar-accent hover:text-sidebar-accent-foreground " \
                "focus-visible:ring-2 active:bg-sidebar-accent active:text-sidebar-accent-foreground " \
                "disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none " \
                "aria-disabled:opacity-50 data-active:bg-sidebar-accent data-active:font-medium " \
                "data-active:text-sidebar-accent-foreground [&_svg]:size-4 [&_svg]:shrink-0 " \
                "[&>span:last-child]:truncate"
        element :menu_button_default, "h-8 text-sm"

        # The item-corner action + badge (W5b commit 3) - the peer/menu-button
        # and group/menu-item consumers, source-exact (base-vega).
        element :menu_action,
                "absolute top-1.5 right-1 flex aspect-square w-5 items-center justify-center rounded-md " \
                "p-0 text-sidebar-foreground ring-sidebar-ring outline-hidden transition-transform " \
                "group-data-[collapsible=icon]:hidden peer-hover/menu-button:text-sidebar-accent-foreground " \
                "peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 " \
                "peer-data-[size=sm]/menu-button:top-1 after:absolute after:-inset-2 " \
                "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:ring-2 " \
                "md:after:hidden [&>svg]:size-4 [&>svg]:shrink-0"
        element :menu_action_hover,
                "group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 " \
                "peer-data-active/menu-button:text-sidebar-accent-foreground aria-expanded:opacity-100 " \
                "md:opacity-0"
        element :menu_badge,
                "pointer-events-none absolute right-1 flex h-5 min-w-5 items-center justify-center " \
                "rounded-md px-1 text-xs font-medium text-sidebar-foreground tabular-nums select-none " \
                "group-data-[collapsible=icon]:hidden peer-hover/menu-button:text-sidebar-accent-foreground " \
                "peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 " \
                "peer-data-[size=sm]/menu-button:top-1 peer-data-active/menu-button:text-sidebar-accent-foreground"
        element :menu_button_sm, "h-7 text-xs"
        element :menu_button_lg, "h-12 text-sm group-data-[collapsible=icon]:p-0!"

        element :menu_sub, "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l " \
                           "border-sidebar-border px-2.5 py-0.5 group-data-[collapsible=icon]:hidden"
        element :menu_sub_item, "relative"
        element :menu_sub_button, "flex h-7 min-w-0 -translate-x-px items-center gap-2 overflow-hidden " \
                                  "rounded-md px-2 text-sidebar-foreground outline-hidden ring-sidebar-ring " \
                                  "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground " \
                                  "focus-visible:ring-2 active:bg-sidebar-accent " \
                                  "active:text-sidebar-accent-foreground disabled:pointer-events-none " \
                                  "disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 " \
                                  "data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground " \
                                  "[&>svg]:size-4 [&>svg]:shrink-0 [&>span:last-child]:truncate text-sm"

        def self.menu_button_size(value)
          css(:"menu_button_#{value}")
        end
      end
    end
  end
end
