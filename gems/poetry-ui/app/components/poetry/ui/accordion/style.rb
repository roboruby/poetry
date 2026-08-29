# frozen_string_literal: true

module Poetry
  module Ui
    module Accordion
      # Re-expressed through the cn-* theme layer. The panel
      # animation classes ride the theme (the vendored accordion-down/up
      # keyframes still fed by --accordion-panel-height); the chevron's
      # aria-expanded rotation + motion stay inline (state mechanism).
      class Style < Poetry::Core::Style
        # Root hook: several themes (mira, rhea, luma, maia) style the
        # root as a box - the name must compile in EVERY theme, so each
        # fragment carries a rule (default: w-full).
        base "cn-accordion flex flex-col w-full"

        element :item, "cn-accordion-item"

        element :header, "flex"

        # The chevron flips on aria-expanded, not a data attribute: the
        # controller reflects only aria-expanded on the trigger (the
        # data-open/data-closed pair lives on the item and panel).
        element :trigger, "cn-accordion-trigger flex flex-1 items-start justify-between transition-all " \
                          "outline-none disabled:pointer-events-none disabled:opacity-50 " \
                          "[&[aria-expanded=true]>svg]:rotate-180 border border-transparent " \
                          "group/accordion-trigger relative"

        element :indicator, "cn-accordion-trigger-icon pointer-events-none shrink-0 " \
                            "transition-transform duration-200"

        element :content, "cn-accordion-content overflow-hidden"

        element :inner, "cn-accordion-content-inner"
      end
    end
  end
end
