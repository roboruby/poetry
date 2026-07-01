# frozen_string_literal: true

module Poetry
  module Ui
    module Alert
      class Style < Poetry::Core::Style
        base "relative grid w-full grid-cols-[0_1fr] items-start gap-y-0.5 rounded-lg border " \
             "px-4 py-3 text-sm has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] has-[>svg]:gap-x-3 " \
             "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current"

        variant :variant, {
          default: "bg-card text-card-foreground",
          destructive: "bg-card text-destructive [&>svg]:text-current " \
                       "*:data-[slot=alert-description]:text-destructive/90"
        }

        element :title, "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"
        element :description,
                "col-start-2 grid justify-items-start gap-1 text-sm text-muted-foreground [&_p]:leading-relaxed"
      end
    end
  end
end
