# frozen_string_literal: true

module Poetry
  module Ui
    module Avatar
      # shadcn Avatar, re-expressed through the cn-* theme layer.
      # :image keeps poetry's "absolute inset-0" deviation inline (the
      # server-native layered fallback keeps BOTH fallback and image in the
      # DOM, so the image must cover the initials); the after:* ring
      # machinery stays inline per upstream's own split.
      class Style < Poetry::Core::Style
        base "cn-avatar group/avatar relative flex shrink-0 select-none " \
             "after:absolute after:inset-0 after:border after:border-border " \
             "after:mix-blend-darken dark:after:mix-blend-lighten"

        element :image, "cn-avatar-image absolute inset-0 aspect-square size-full object-cover"
        element :fallback, "cn-avatar-fallback flex size-full items-center justify-center " \
                           "text-sm group-data-[size=sm]/avatar:text-xs"
        element :badge, "cn-avatar-badge absolute right-0 bottom-0 z-10 inline-flex items-center " \
                        "justify-center rounded-full bg-blend-color ring-2 select-none"

        # The stack (poetry_avatar_group) + its overflow count.
        element :group, "group/avatar-group flex -space-x-2 " \
                        "*:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background"
        element :group_count, "cn-avatar-group-count relative flex shrink-0 items-center " \
                              "justify-center ring-2 ring-background"
      end
    end
  end
end
