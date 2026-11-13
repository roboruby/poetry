# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # Utility-only: InputGroup, Textarea and Button wear the chrome, so
      # the composer adds no theme CSS. What is here is mechanics: the
      # field's one-row floor and its growth ceiling (past it the field
      # scrolls), the action slot's place at the end of the footer row, and
      # the Send button's dimming while the field is empty.
      class Style < Poetry::Core::Style
        base "group/composer w-full min-w-0"

        element :input, "max-h-48 min-h-10"

        element :action, "ms-auto flex shrink-0 items-center gap-1"

        element :send, "group-data-[empty]/composer:opacity-50"
      end
    end
  end
end
