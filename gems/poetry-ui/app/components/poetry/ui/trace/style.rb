# frozen_string_literal: true

module Poetry
  module Ui
    module Trace
      # The Trace dictionary: upstream's trace anatomy (shadcn@4.23.0) - the
      # structural classes per part, transcribed from the styled source. The
      # look (gaps, type size, focus rings, the detail's rail) lives in each
      # theme's cn-trace-* rules. Title, description and the collapsible
      # wrapper carry no hook: no theme styles them.
      class Style < Poetry::Core::Style
        base "cn-trace flex w-full min-w-0 flex-col *:has-[>[data-slot=trace-line]]:flex " \
             "*:has-[>[data-slot=trace-line]]:w-fit *:has-[>[data-slot=trace-line]]:max-w-full " \
             "*:has-[>[data-slot=trace-line]]:min-w-0 *:has-[>[data-slot=trace-line]]:text-left " \
             "*:has-[>[data-slot=trace-line]]:outline-none"

        element :line, "cn-trace-line flex w-fit max-w-full min-w-0 items-center text-muted-foreground " \
                       "transition-colors in-[a,button]:cursor-pointer in-[a:hover,button:hover]:text-foreground " \
                       "data-[status=error]:text-destructive " \
                       "data-[status=error]:in-[a:hover,button:hover]:text-destructive " \
                       "data-[status=pending]:opacity-60 data-[status=running]:*:data-[slot=trace-title]:shimmer"
        element :icon, "cn-trace-icon flex shrink-0 items-center justify-center [&_svg]:pointer-events-none"
        element :title, "min-w-0 truncate motion-reduce:shimmer-none"
        element :description, "shrink-0 text-muted-foreground/70 tabular-nums"
        element :collapsible, "flex w-full min-w-0 flex-col"
        element :collapsible_trigger, "cn-trace-collapsible-trigger group/trace-collapsible-trigger flex w-fit " \
                                      "max-w-full min-w-0 cursor-pointer items-center text-left " \
                                      "text-muted-foreground transition-colors outline-none hover:text-foreground " \
                                      "has-[[data-status=error]]:text-destructive"
        # The trigger's chevron is a trace icon that turns with aria-expanded.
        element :chevron, "transition-transform group-aria-expanded/trace-collapsible-trigger:rotate-90"
        element :collapsible_content, "cn-trace-collapsible-content h-(--collapsible-panel-height) min-w-0 " \
                                      "overflow-hidden transition-[height] data-ending-style:h-0 " \
                                      "data-starting-style:h-0"
        element :collapsible_content_inner, "cn-trace-collapsible-content-inner min-w-0 wrap-break-word " \
                                            "text-muted-foreground"
      end
    end
  end
end
