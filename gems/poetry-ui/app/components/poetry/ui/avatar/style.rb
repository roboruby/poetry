# frozen_string_literal: true

module Poetry
  module Ui
    module Avatar
      # shadcn Avatar (base-vega), source-exact - except :image gains
      # "absolute inset-0": the server-native layered fallback keeps BOTH the
      # fallback and the image in the DOM (Base UI swaps them client-side),
      # so the image must cover the initials, not sit beside them.
      class Style < Poetry::Core::Style
        base "group/avatar relative flex size-8 shrink-0 rounded-full select-none " \
             "after:absolute after:inset-0 after:rounded-full after:border after:border-border " \
             "after:mix-blend-darken data-[size=lg]:size-10 data-[size=sm]:size-6 " \
             "dark:after:mix-blend-lighten"

        element :image, "absolute inset-0 aspect-square size-full rounded-full object-cover"
        element :fallback, "flex size-full items-center justify-center rounded-full bg-muted " \
                           "text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs"
        element :badge, "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center " \
                        "rounded-full bg-primary text-primary-foreground bg-blend-color ring-2 " \
                        "ring-background select-none " \
                        "group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden " \
                        "group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2 " \
                        "group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2"

        # The stack (poetry_avatar_group) + its overflow count.
        element :group, "group/avatar-group flex -space-x-2 " \
                        "*:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background"
        element :group_count, "relative flex size-8 shrink-0 items-center justify-center rounded-full " \
                              "bg-muted text-sm text-muted-foreground ring-2 ring-background " \
                              "group-has-data-[size=lg]/avatar-group:size-10 " \
                              "group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 " \
                              "group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 " \
                              "group-has-data-[size=sm]/avatar-group:[&>svg]:size-3"
      end
    end
  end
end
