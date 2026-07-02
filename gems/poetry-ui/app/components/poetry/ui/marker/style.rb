# frozen_string_literal: true

module Poetry
  module Ui
    module Marker
      # The Marker dictionary - shadcn new-york-v4 AI-chat set,
      # source-validated 2026-07-01 (Marker). The
      # separator lines are ::before/::after pseudo-elements (AT never
      # sees them - the a11y contract announces the LABEL, never a
      # separator role).
      class Style < Poetry::Core::Style
        base "group/marker relative flex min-h-4 w-full items-center gap-2 text-left text-sm " \
             "text-muted-foreground [&_svg:not([class*='size-'])]:size-4 " \
             "[a]:underline [a]:underline-offset-3 [a]:hover:text-foreground"

        variant :variant, {
          default: "",
          separator: "before:mr-1 before:h-px before:min-w-0 before:flex-1 before:bg-border " \
                     "after:ml-1 after:h-px after:min-w-0 after:flex-1 after:bg-border",
          border: "border-b border-border pb-2"
        }

        element :icon, "size-4 shrink-0 [&_svg:not([class*='size-'])]:size-4"

        element :content, "min-w-0 wrap-break-word group-data-[variant=separator]/marker:flex-none " \
                          "group-data-[variant=separator]/marker:text-center " \
                          "*:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground"
      end
    end
  end
end
