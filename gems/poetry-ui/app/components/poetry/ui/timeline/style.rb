# frozen_string_literal: true

module Poetry
  module Ui
    module Timeline
      # Utility-only (the Separator/Spinner rule): no upstream cn hook
      # exists for a Timeline, so the surface is structural utilities on
      # semantic tokens - data-slot selectors are the restyle seam. Both
      # orientations live in ONE dictionary via the named-group pattern
      # (ReUI's Timeline idiom): the root carries group/timeline +
      # data-orientation, each item group/timeline-item + data-completed,
      # and every element restyles itself off those two markers - so one
      # attribute flip re-lays the whole sequence.
      class Style < Poetry::Core::Style
        base "group/timeline flex"

        variant :orientation, {
          vertical: "flex-col",
          horizontal: "w-full flex-row"
        }

        element :item, "group/timeline-item relative flex flex-1 flex-col gap-0.5 " \
                       "group-data-[orientation=vertical]/timeline:ps-9 " \
                       "group-data-[orientation=vertical]/timeline:not-last:pb-7 " \
                       "group-data-[orientation=horizontal]/timeline:pt-9 " \
                       "group-data-[orientation=horizontal]/timeline:not-last:pe-8"
        element :indicator, "absolute top-0 left-0 flex size-6 items-center justify-center " \
                            "rounded-full border border-border bg-background " \
                            "text-muted-foreground " \
                            "group-data-[completed]/timeline-item:border-primary " \
                            "group-data-[completed]/timeline-item:text-primary"
        element :indicator_dot, "size-1.5 rounded-full bg-current"
        element :indicator_icon, "size-3.5"
        element :separator, "absolute bg-border group-last/timeline-item:hidden " \
                            "group-data-[completed]/timeline-item:bg-primary " \
                            "group-data-[orientation=vertical]/timeline:top-7 " \
                            "group-data-[orientation=vertical]/timeline:left-3 " \
                            "group-data-[orientation=vertical]/timeline:h-[calc(100%-2rem)] " \
                            "group-data-[orientation=vertical]/timeline:w-px " \
                            "group-data-[orientation=vertical]/timeline:-translate-x-1/2 " \
                            "group-data-[orientation=horizontal]/timeline:top-3 " \
                            "group-data-[orientation=horizontal]/timeline:left-7 " \
                            "group-data-[orientation=horizontal]/timeline:h-px " \
                            "group-data-[orientation=horizontal]/timeline:w-[calc(100%-2rem)] " \
                            "group-data-[orientation=horizontal]/timeline:-translate-y-1/2"
        element :header, "flex flex-wrap items-baseline gap-x-2 gap-y-0.5 " \
                         "group-data-[orientation=vertical]/timeline:min-h-6"
        element :title, "text-sm font-medium"
        element :time, "text-xs font-medium text-muted-foreground"
        element :content, "text-sm text-muted-foreground"
      end
    end
  end
end
