# frozen_string_literal: true

module Poetry
  module Ui
    module ButtonGroup
      # Re-expressed through the cn-* theme layer. One documented
      # deviation from upstream's literal split: upstream ships the
      # orientation corner-chains inline AND under cn names; poetry puts
      # them theme-side only (pure radius/border design - the theme owns
      # them, nothing is emitted twice).
      class Style < Poetry::Core::Style
        base "cn-button-group flex w-fit items-stretch *:focus-visible:relative *:focus-visible:z-10 " \
             "[&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1"

        variant :orientation, {
          horizontal: "cn-button-group-orientation-horizontal",
          vertical: "cn-button-group-orientation-vertical"
        }

        element :text, "cn-button-group-text flex items-center [&_svg]:pointer-events-none"
        element :separator, "cn-button-group-separator relative self-stretch " \
                            "data-horizontal:mx-px data-horizontal:w-auto " \
                            "data-vertical:my-px data-vertical:h-auto"
      end
    end
  end
end
