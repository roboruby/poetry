# frozen_string_literal: true

module Poetry
  module Ui
    module Sources
      # No theme layer of its own: the control wears the ghost Button's
      # dictionary, each number is a Citation and each title a Link, so
      # the themes dress every part. What is here lays the list out: a row
      # per source, the number held to the first line, and the address
      # and the quote muted under the title.
      class Style < Poetry::Core::Style
        base "w-full min-w-0 text-sm"

        element :trigger, "-ms-2.5"
        element :content, "min-w-0"

        element :list, "mt-2 flex flex-col gap-2"
        element :item, "flex min-w-0 items-baseline gap-2"
        element :body, "flex min-w-0 flex-col gap-0.5"
        element :heading, "flex min-w-0 flex-wrap items-baseline gap-x-2"
        element :title, "min-w-0 break-words font-medium"
        element :site, "text-xs text-muted-foreground"
        element :description, "text-muted-foreground"
      end
    end
  end
end
