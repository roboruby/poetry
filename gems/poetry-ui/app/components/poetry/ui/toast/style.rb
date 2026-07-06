# frozen_string_literal: true

module Poetry
  module Ui
    module Toast
      # Re-expressed through the cn-* theme layer (N11) - still poetry's
      # OWN visual (the source ships the sonner library). The corner-aware
      # slide chains ride the theme with the rest of the treatment (they
      # key on the TOASTER's data-position through group/toaster at
      # runtime); the default variant stays an empty string (the base IS
      # the default - nothing to name).
      class Style < Poetry::Core::Style
        base "cn-toast pointer-events-auto relative flex w-full items-start outline-hidden"

        variant :variant, {
          default: "",
          success: "cn-toast-variant-success",
          info: "cn-toast-variant-info",
          warning: "cn-toast-variant-warning",
          destructive: "cn-toast-variant-destructive"
        }

        element :icon, "cn-toast-icon flex shrink-0 items-center justify-center"
        element :body, "cn-toast-body flex min-w-0 flex-1 flex-col"
        element :title, "cn-toast-title"
        element :description, "cn-toast-description"
        element :action, "shrink-0 self-start"
        element :close, "shrink-0 self-start"
      end
    end
  end
end
