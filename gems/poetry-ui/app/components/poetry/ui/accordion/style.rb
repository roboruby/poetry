# frozen_string_literal: true

module Poetry
  module Ui
    module Accordion
      # The Accordion dictionary - shadcn new-york-v4, source-validated
      # 2026-07-02 (Accordion). The panel animation
      # rides the vendored accordion-down/up keyframes, fed by the
      # measured --accordion-panel-height var (the presence helper).
      class Style < Poetry::Core::Style
        element :item, "border-b last:border-b-0"

        element :header, "flex"

        # The chevron flips on aria-expanded, not a data attribute: the
        # controller reflects only aria-expanded on the trigger (the
        # data-open/data-closed pair lives on the item and panel).
        element :trigger, "flex flex-1 items-start justify-between gap-4 rounded-md py-4 text-left text-sm " \
                          "font-medium transition-all outline-none hover:underline focus-visible:border-ring " \
                          "focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none " \
                          "disabled:opacity-50 [&[aria-expanded=true]>svg]:rotate-180"

        element :indicator, "pointer-events-none size-4 shrink-0 translate-y-0.5 text-muted-foreground " \
                            "transition-transform duration-200"

        element :content, "overflow-hidden text-sm data-closed:animate-accordion-up " \
                          "data-open:animate-accordion-down"

        element :inner, "pt-0 pb-4"
      end
    end
  end
end
