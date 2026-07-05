# frozen_string_literal: true

module Poetry
  module Ui
    module Item
      # shadcn Item (base-vega), source-exact. The variant/size axes ride
      # data-variant/data-size (emitted by the component, styled here via
      # the group/item custom-variant selectors baked into the strings).
      class Style < Poetry::Core::Style
        base "group/item flex w-full flex-wrap items-center rounded-md border text-sm " \
             "transition-colors duration-100 outline-none focus-visible:border-ring " \
             "focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-muted"

        variant :variant, {
          default: "border-transparent",
          outline: "border-border",
          muted: "border-transparent bg-muted/50"
        }

        variant :size, {
          default: "gap-3.5 px-4 py-3.5",
          sm: "gap-2.5 px-3 py-2.5",
          xs: "gap-2 px-2.5 py-2 in-data-[slot=dropdown-menu-content]:p-0"
        }

        element :media, "flex shrink-0 items-center justify-center gap-2 " \
                        "group-has-data-[slot=item-description]/item:translate-y-0.5 " \
                        "group-has-data-[slot=item-description]/item:self-start [&_svg]:pointer-events-none"
        element :media_default, "bg-transparent"
        element :media_icon, "[&_svg:not([class*='size-'])]:size-4"
        element :media_image, "size-10 overflow-hidden rounded-sm group-data-[size=sm]/item:size-8 " \
                              "group-data-[size=xs]/item:size-6 [&_img]:size-full [&_img]:object-cover"
        element :content, "flex flex-1 flex-col gap-1 group-data-[size=xs]/item:gap-0 " \
                          "[&+[data-slot=item-content]]:flex-none"
        element :title, "line-clamp-1 flex w-fit items-center gap-2 text-sm leading-snug font-medium " \
                        "underline-offset-4"
        element :description, "line-clamp-2 text-left text-sm leading-normal font-normal " \
                              "text-muted-foreground group-data-[size=xs]/item:text-xs [&>a]:underline " \
                              "[&>a]:underline-offset-4 [&>a:hover]:text-primary"
        element :actions, "flex items-center gap-2"
        element :header, "flex basis-full items-center justify-between gap-2"
        element :footer, "flex basis-full items-center justify-between gap-2"

        # The list wrapper + row separator (poetry_item_group / _separator).
        # Upstream also stamps a group/item-group marker; nothing consumes it
        # (verified against the full base-vega set), so it compiles to no CSS
        # and is dropped here - restore it when a consumer lands.
        element :group, "flex w-full flex-col gap-4 has-data-[size=sm]:gap-2.5 " \
                        "has-data-[size=xs]:gap-2"
        element :separator, "my-2"
      end
    end
  end
end
