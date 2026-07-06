# frozen_string_literal: true

module Poetry
  module Ui
    module Message
      # Re-expressed through the cn-* theme layer (N11). The :has()/group
      # context choreography stays inline (footer presence lifts the
      # avatar; the align axis flips rows and self-alignment); type,
      # spacing, and the ghost-Bubble padding collapse ride the theme.
      class Style < Poetry::Core::Style
        base "cn-message group/message relative flex w-full min-w-0 data-[align=end]:flex-row-reverse"

        element :group, "cn-message-group flex min-w-0 flex-col"

        element :avatar, "cn-message-avatar flex w-fit shrink-0 items-center justify-center self-end " \
                         "overflow-hidden rounded-full bg-muted " \
                         "group-has-data-[slot=message-footer]/message:-translate-y-8"

        element :content, "cn-message-content flex w-full min-w-0 flex-col wrap-break-word " \
                          "group-data-[align=end]/message:*:data-slot:self-end"

        element :header, "cn-message-header flex max-w-full min-w-0 items-center"

        element :footer, "cn-message-footer flex max-w-full min-w-0 items-center " \
                         "group-data-[align=end]/message:justify-end"
      end
    end
  end
end
