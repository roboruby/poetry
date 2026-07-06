# frozen_string_literal: true

module Poetry
  module Ui
    module MessageScroller
      # Re-expressed through the cn-* theme layer (N11) - minimally: the
      # 4-state scroll machine's whole surface is machinery (viewport
      # containment/scrollbar choreography, row content-visibility, the
      # jump button's show/hide translate dance - upstream keeps every one
      # of those inline too). Only the row rhythm is design: gap-8 rides
      # .cn-message-scroller-content.
      class Style < Poetry::Core::Style
        # Source also stamps a group/message-scroller named-group marker;
        # dropped until a dictionary consumer references it - an unconsumed
        # named group never reaches the compiled CSS, and the verify gate
        # (rightly) rejects classes no build can produce.
        base "relative flex size-full min-h-0 flex-col overflow-hidden"

        element :viewport, "size-full min-h-0 min-w-0 scroll-fade-b scrollbar-thin scrollbar-gutter-stable " \
                           "overflow-y-auto overscroll-contain contain-content data-autoscrolling:scrollbar-none"

        element :content, "cn-message-scroller-content flex h-max min-h-full flex-col"

        element :item, "min-w-0 shrink-0 [contain-intrinsic-size:auto_10rem] [content-visibility:auto]"

        element :button, "absolute inset-s-1/2 -translate-x-1/2 border-border bg-background text-foreground " \
                         "transition-[translate,scale,opacity] duration-200 hover:bg-muted hover:text-foreground " \
                         "data-[active=false]:pointer-events-none data-[active=false]:scale-95 " \
                         "data-[active=false]:opacity-0 data-[active=false]:duration-400 " \
                         "data-[active=false]:ease-[cubic-bezier(0.7,0,0.84,0)] " \
                         "data-[active=true]:translate-y-0 data-[active=true]:scale-100 " \
                         "data-[active=true]:opacity-100 data-[active=true]:ease-[cubic-bezier(0.23,1,0.32,1)] " \
                         "data-[direction=end]:bottom-4 data-[direction=end]:data-[active=false]:translate-y-full " \
                         "data-[direction=start]:top-4 data-[direction=start]:data-[active=false]:-translate-y-full " \
                         "rtl:translate-x-1/2 data-[direction=start]:[&_svg]:rotate-180"
      end
    end
  end
end
