# frozen_string_literal: true

module Poetry
  module Ui
    module Link
      class Style < Poetry::Core::Style
        base "inline-flex items-center gap-1 rounded-sm text-primary underline-offset-4 " \
             "outline-none transition-colors " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"

        variant :underline, {
          hover: "no-underline hover:underline",
          always: "underline",
          none: "no-underline"
        }
      end
    end
  end
end
