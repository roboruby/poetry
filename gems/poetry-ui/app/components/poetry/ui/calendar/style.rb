# frozen_string_literal: true

module Poetry
  module Ui
    module Calendar
      # poetry's OWN calendar engine (N9 W6), re-expressed through the cn-*
      # theme layer (N11). The cell-size var + grid geometry stay inline
      # (mechanism); the day-button's whole state chain (selected / today /
      # outside / range tints) rides .cn-calendar-day-button TOGETHER
      # (split-side rule - the tints override each other in-layer). The
      # in-popover bg override stays inline per upstream's own root split.
      class Style < Poetry::Core::Style
        # group/calendar stays dropped (no consumer; the compiled-CSS gate
        # flags markers nothing consumes). It returns with a consumer.
        base "cn-calendar bg-background [--cell-size:--spacing(8)] w-fit " \
             "in-data-[slot=popover-content]:bg-transparent"

        element :nav, "flex items-center justify-between gap-1 pb-2"
        element :nav_button, "size-(--cell-size) p-0 select-none aria-disabled:opacity-50"
        element :caption, "cn-calendar-caption flex-1 text-center select-none"
        # The dropdown caption (caption_layout: :dropdown) - the NativeSelect
        # pair centered where the label sits; the selects carry their own
        # themed treatment.
        element :caption_dropdowns, "flex flex-1 items-center justify-center gap-1.5"

        element :grid, "w-full border-collapse"
        element :weekdays, "flex"
        element :weekday, "cn-calendar-weekday flex-1 select-none flex items-center justify-center " \
                          "h-(--cell-size)"
        element :week, "mt-2 flex w-full"
        element :day_cell, "relative aspect-square h-full w-full flex-1 p-0 text-center select-none"

        # The day button: ghost, with the selected/today/outside/range
        # states - the whole treatment in the theme rule.
        element :day, "cn-calendar-day-button relative isolate z-10 flex aspect-square size-auto " \
                      "w-full min-w-(--cell-size) items-center justify-center border-0 outline-none " \
                      "disabled:pointer-events-none"
      end
    end
  end
end
