# frozen_string_literal: true

module Poetry
  module Ui
    module Card
      class Style < Poetry::Core::Style
        base "flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm"

        element :header, "grid auto-rows-min grid-rows-[auto_auto] items-start gap-1.5 px-6 " \
                         "has-data-[slot=card-action]:grid-cols-[1fr_auto]"
        element :title, "font-semibold leading-none"
        element :description, "text-sm text-muted-foreground"
        element :action, "col-start-2 row-span-2 row-start-1 self-start justify-self-end"
        element :content, "px-6"
        element :footer, "flex items-center px-6"
      end
    end
  end
end
