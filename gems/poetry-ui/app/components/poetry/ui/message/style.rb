# frozen_string_literal: true

module Poetry
  module Ui
    module Message
      # The Message dictionary - shadcn new-york-v4 AI-chat set,
      # source-validated 2026-07-01 (Message). No cva:
      # one align axis as data-[align] selectors; the complexity is the
      # :has()/group context selectors (footer presence lifts the avatar;
      # a descendant ghost Bubble collapses header/footer padding - the
      # cross-contract dependency on Bubble's data-variant).
      class Style < Poetry::Core::Style
        base "group/message relative flex w-full min-w-0 gap-2 text-sm data-[align=end]:flex-row-reverse"

        element :group, "flex min-w-0 flex-col gap-2"

        element :avatar, "flex w-fit min-w-8 shrink-0 items-center justify-center self-end overflow-hidden " \
                         "rounded-full bg-muted group-has-data-[slot=message-footer]/message:-translate-y-8"

        element :content, "flex w-full min-w-0 flex-col gap-2.5 wrap-break-word " \
                          "group-data-[align=end]/message:*:data-slot:self-end"

        element :header, "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground " \
                         "group-has-data-[variant=ghost]/message:px-0"

        element :footer, "flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground " \
                         "group-has-data-[variant=ghost]/message:px-0 group-data-[align=end]/message:justify-end"
      end
    end
  end
end
