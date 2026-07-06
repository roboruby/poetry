# frozen_string_literal: true

module Poetry
  module Ui
    module Bubble
      # Re-expressed through the cn-* theme layer (N11). The variant rules
      # (root classes styling the content child via *:data-[slot] selectors,
      # incl. the tinted relative-color math flagged to the contrast gate)
      # ride the theme; the align choreography and the reactions' side/align
      # translate positioning stay inline (mechanism).
      class Style < Poetry::Core::Style
        base "cn-bubble group/bubble relative flex w-fit min-w-0 flex-col " \
             "group-data-[align=end]/message:self-end data-[align=end]:self-end"

        variant :variant, {
          default: "cn-bubble-variant-default",
          secondary: "cn-bubble-variant-secondary",
          muted: "cn-bubble-variant-muted",
          tinted: "cn-bubble-variant-tinted",
          outline: "cn-bubble-variant-outline",
          ghost: "cn-bubble-variant-ghost",
          destructive: "cn-bubble-variant-destructive"
        }

        element :group, "cn-bubble-group flex min-w-0 flex-col"

        element :content, "cn-bubble-content w-fit max-w-full min-w-0 overflow-hidden wrap-break-word " \
                          "group-data-[align=end]/bubble:self-end " \
                          "[button]:text-left [button,a]:transition-colors [button,a]:outline-none"

        # The side x align positioning stays inline (translate mechanism);
        # the pill treatment rides .cn-bubble-reactions.
        element :reactions, "cn-bubble-reactions absolute z-10 flex w-fit shrink-0 items-center " \
                            "justify-center data-[side=top]:top-0 data-[side=top]:-translate-y-3/4 " \
                            "data-[side=bottom]:bottom-0 data-[side=bottom]:translate-y-3/4 " \
                            "data-[align=start]:left-3 data-[align=end]:right-3"
      end
    end
  end
end
