# frozen_string_literal: true

module Poetry
  module Ui
    module Menubar
      # Re-expressed through the cn-* theme layer (N11), the source quirks
      # preserved in the theme rules verbatim (content omits
      # data-closed:animate-out, checkbox/radio round with rounded-xs, the
      # sub-trigger has no [&_svg] block). :menu keeps display:contents
      # inline - the one poetry addition (controller host erased from
      # layout + the a11y tree).
      class Style < Poetry::Core::Style
        base "cn-menubar flex items-center"

        # POETRY ADDITION: the logical Menu grouping needs a host element
        # for its menu + popper controllers; display:contents erases it
        # from layout and the a11y tree (Radix renders no element here).
        element :menu, "contents"

        element :trigger, "cn-menubar-trigger flex items-center outline-hidden select-none"

        element :content, "cn-menubar-content cn-menu-translucent z-50 " \
                          "origin-(--transform-origin) overflow-hidden"

        # group/menubar-item (N12): bare marker, no CSS - the vega shortcut
        # re-color (group-focus/menubar-item) keys on it.
        element :item, "cn-menubar-item group/menubar-item relative flex cursor-default " \
                       "items-center outline-hidden select-none data-[disabled]:pointer-events-none " \
                       "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :checkbox_item, "cn-menubar-checkbox-item relative flex cursor-default items-center " \
                                "outline-hidden select-none data-[disabled]:pointer-events-none " \
                                "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :radio_item, "cn-menubar-radio-item relative flex cursor-default items-center " \
                             "outline-hidden select-none data-[disabled]:pointer-events-none " \
                             "data-[disabled]:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0"

        element :label, "cn-menubar-label"

        element :separator, "cn-menubar-separator"

        element :shortcut, "cn-menubar-shortcut"

        # DELTA vs the family: outline-none (not -hidden), no [&_svg] block
        # (source-exact).
        element :sub_trigger, "cn-menubar-sub-trigger flex cursor-default items-center " \
                              "outline-none select-none"

        element :sub_content, "cn-menubar-sub-content z-50 " \
                              "origin-(--transform-origin) overflow-hidden"

        # Source-exact wrapper span (anonymous in new-york-v4; poetry names
        # it menubar-item-indicator - the self-identification rule).
        element :item_indicator, "pointer-events-none absolute " \
                                 "flex items-center justify-center"

        # POETRY ADDITION (family convention): the indicator stays in the
        # DOM; the parent item's data-checked/data-unchecked pair drives
        # visibility.
        element :item_indicator_state, "[[data-unchecked]>&]:hidden"

        # The source's inline lucide icon classes, named per part. DELTA:
        # the menubar sub chevron is ml-auto h-4 w-4 (source-exact).
        element :indicator_check, "size-4"
        element :indicator_circle, "size-2 fill-current"
        element :sub_indicator, "ml-auto h-4 w-4"
      end
    end
  end
end
