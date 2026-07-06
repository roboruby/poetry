# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # Re-expressed through the cn-* theme layer (N11). One element: the
      # preview panel on the popover token scheme; w-64 stays inline (the
      # caller-overridable width default, upstream's split), the origin
      # class binds through tokens/aliases.css and stays inline.
      class Style < Poetry::Core::Style
        element :content, "cn-hover-card-content z-50 w-64 " \
                          "origin-(--radix-hover-card-content-transform-origin) outline-hidden"
      end
    end
  end
end
