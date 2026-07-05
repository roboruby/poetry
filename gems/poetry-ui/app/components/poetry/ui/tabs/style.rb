# frozen_string_literal: true

module Poetry
  module Ui
    module Tabs
      # shadcn Tabs (base-vega), source-exact. The group/tabs and
      # group/tabs-list markers ARE consumed (the trigger/list strings key
      # on them); orientation styling rides the data-horizontal/vertical
      # bridge variants matching the rendered data-orientation.
      class Style < Poetry::Core::Style
        base "group/tabs flex gap-2 data-horizontal:flex-col"

        element :list, "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg " \
                       "p-[3px] text-muted-foreground group-data-horizontal/tabs:h-9 " \
                       "group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col " \
                       "data-[variant=line]:rounded-none"
        element :list_default, "bg-muted"
        element :list_line, "gap-1 bg-transparent"

        element :trigger,
                "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 " \
                "rounded-md border border-transparent px-2 py-1 text-sm font-medium whitespace-nowrap " \
                "text-foreground/60 transition-all group-data-vertical/tabs:w-full " \
                "group-data-vertical/tabs:justify-start hover:text-foreground " \
                "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                "focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none " \
                "disabled:opacity-50 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 " \
                "aria-disabled:pointer-events-none aria-disabled:opacity-50 dark:text-muted-foreground " \
                "dark:hover:text-foreground " \
                "group-data-[variant=default]/tabs-list:data-active:shadow-sm " \
                "group-data-[variant=line]/tabs-list:data-active:shadow-none " \
                "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 " \
                "group-data-[variant=line]/tabs-list:bg-transparent " \
                "group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
                "dark:group-data-[variant=line]/tabs-list:data-active:border-transparent " \
                "dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent " \
                "data-active:bg-background data-active:text-foreground dark:data-active:border-input " \
                "dark:data-active:bg-input/30 dark:data-active:text-foreground " \
                "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity " \
                "group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:bottom-[-5px] " \
                "group-data-horizontal/tabs:after:h-0.5 group-data-vertical/tabs:after:inset-y-0 " \
                "group-data-vertical/tabs:after:-right-1 group-data-vertical/tabs:after:w-0.5 " \
                "group-data-[variant=line]/tabs-list:data-active:after:opacity-100"

        element :content, "flex-1 text-sm outline-none"
      end
    end
  end
end
