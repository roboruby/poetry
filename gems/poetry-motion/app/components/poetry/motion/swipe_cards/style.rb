# frozen_string_literal: true

module Poetry
  module Motion
    module SwipeCards
      # The stack's classes: the cards share one cell; the depth lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "group/swipe flex flex-col items-stretch gap-4 rounded-xl outline-none focus-visible:ring-[3px] " \
             "focus-visible:ring-ring/50"
        element :deck, "grid"
        element :actions, "flex justify-center gap-2"
        element :card, "[grid-area:1/1] touch-none select-none"
        element :empty, "[grid-area:1/1] hidden place-self-center text-sm text-muted-foreground " \
                        "group-data-empty/swipe:block"
      end
    end
  end
end
