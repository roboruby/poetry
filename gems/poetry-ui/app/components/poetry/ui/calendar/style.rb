# frozen_string_literal: true

module Poetry
  module Ui
    module Calendar
      # poetry's OWN calendar dictionary (N9 W6). shadcn's calendar is
      # welded to react-day-picker's classNames map + rdp-* internals; the
      # W6 decision replaces the engine with a server-rendered month table,
      # so this is a clean re-derivation of the SAME visual (cell size/
      # radius vars, the day-button states) as a semantic grid - not a port
      # of the day-picker class map.
      class Style < Poetry::Core::Style
        base "group/calendar bg-background p-3 [--cell-size:--spacing(8)] w-fit " \
             "in-data-[slot=popover-content]:bg-transparent"

        element :nav, "flex items-center justify-between gap-1 pb-2"
        element :nav_button, "size-(--cell-size) p-0 select-none aria-disabled:opacity-50"
        element :caption, "flex-1 text-center text-sm font-medium select-none"

        element :grid, "w-full border-collapse"
        element :weekdays, "flex"
        element :weekday, "flex-1 rounded-md text-[0.8rem] font-normal text-muted-foreground select-none " \
                          "flex items-center justify-center h-(--cell-size)"
        element :week, "mt-2 flex w-full"
        element :day_cell, "relative aspect-square h-full w-full flex-1 p-0 text-center select-none"

        # The day button: ghost, with the selected/today/outside/range
        # states. selected fills primary; today gets the muted ring; outside
        # is muted; range parts (v2) tint the muted band.
        element :day, "relative isolate z-10 flex aspect-square size-auto w-full min-w-(--cell-size) " \
                      "items-center justify-center rounded-md border-0 text-sm leading-none font-normal " \
                      "outline-none hover:bg-accent hover:text-accent-foreground " \
                      "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                      "disabled:pointer-events-none disabled:text-muted-foreground disabled:opacity-50 " \
                      "data-today:bg-muted data-today:text-foreground " \
                      "data-outside:text-muted-foreground " \
                      "data-selected:bg-primary data-selected:text-primary-foreground " \
                      "data-selected:hover:bg-primary data-selected:hover:text-primary-foreground " \
                      "data-range-start:rounded-l-md data-range-start:bg-primary " \
                      "data-range-start:text-primary-foreground data-range-middle:rounded-none " \
                      "data-range-middle:bg-muted data-range-middle:text-foreground " \
                      "data-range-end:rounded-r-md data-range-end:bg-primary data-range-end:text-primary-foreground"
      end
    end
  end
end
