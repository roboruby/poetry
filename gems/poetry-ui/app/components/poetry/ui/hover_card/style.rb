# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # Re-expressed through the cn-* theme layer (N11). One element: the
      # preview panel on the popover token scheme; the origin class binds
      # through tokens/aliases.css and stays inline. Width moved theme-side
      # at N12 W2 (mira/rhea widen to w-72; every fragment owns it) -
      # caller w-* classes still win from the utilities layer.
      class Style < Poetry::Core::Style
        element :content, "cn-hover-card-content z-50 " \
                          "origin-(--radix-hover-card-content-transform-origin) outline-hidden"
      end
    end
  end
end
