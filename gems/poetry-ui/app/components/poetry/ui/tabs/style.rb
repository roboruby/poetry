# frozen_string_literal: true

module Poetry
  module Ui
    module Tabs
      # Re-expressed through the cn-* theme layer (N11). The group/tabs and
      # group/tabs-list markers stay inline (the theme rules key on them);
      # the trigger's whole text-color cluster moved theme-side TOGETHER
      # (split-side rule: the base dims must lose to data-active in-layer).
      # The after:* line-indicator geometry stays inline except its paint.
      # The indicator's OPACITY PAIR (rest 0 / active 100) lives fully
      # inline: the rest state is a utility, so a theme-side activation
      # sits in layer(base) and loses to it unconditionally - the exact
      # split-side violation that shipped the line variant with an
      # invisible indicator until 2026-08-14.
      class Style < Poetry::Core::Style
        base "cn-tabs group/tabs flex data-horizontal:flex-col"

        element :list, "cn-tabs-list group/tabs-list inline-flex w-fit items-center justify-center " \
                       "group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col"
        element :list_default, "cn-tabs-list-variant-default"
        element :list_line, "cn-tabs-list-variant-line"

        element :trigger,
                "cn-tabs-trigger relative inline-flex h-[calc(100%-1px)] flex-1 items-center " \
                "justify-center whitespace-nowrap transition-all " \
                "group-data-vertical/tabs:w-full group-data-vertical/tabs:justify-start " \
                "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
                "focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none " \
                "disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 " \
                "[&_svg]:pointer-events-none [&_svg]:shrink-0 " \
                "after:absolute after:opacity-0 after:transition-opacity " \
                "group-data-[variant=line]/tabs-list:data-active:after:opacity-100"

        element :content, "cn-tabs-content flex-1 outline-none"
      end
    end
  end
end
