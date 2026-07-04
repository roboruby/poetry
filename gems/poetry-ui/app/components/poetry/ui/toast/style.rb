# frozen_string_literal: true

module Poetry
  module Ui
    module Toast
      # The Toast dictionary - poetry's OWN visual (the source ships the
      # sonner library; this keeps sonner's language: the popover token
      # surface, per-variant icon tinting) per the contract's dictionary
      # section. Enter/exit slide direction keys on the TOASTER's
      # data-position through the group/toaster selector - a streamed
      # toast cannot know the corner server-side, so CSS resolves it at
      # runtime. Variant color tokens: success/warning lean on primary and
      # info on muted-foreground for v1 (no semantic success/info/warning
      # roles exist in the theme yet - the contract's open question;
      # destructive is real).
      class Style < Poetry::Core::Style
        base "pointer-events-auto relative flex w-full items-start gap-3 rounded-md " \
             "border bg-popover p-4 text-popover-foreground shadow-lg outline-hidden " \
             "data-open:animate-in data-open:fade-in-0 " \
             "data-open:slide-in-from-bottom-2 " \
             "group-data-[position^=top]/toaster:data-open:slide-in-from-top-2 " \
             "data-closed:animate-out data-closed:fade-out-80 " \
             "data-closed:slide-out-to-bottom-2 " \
             "group-data-[position^=top]/toaster:data-closed:slide-out-to-top-2"

        variant :variant, {
          default: "",
          success: "[&_[data-slot=toast-icon]]:text-primary",
          info: "[&_[data-slot=toast-icon]]:text-muted-foreground",
          warning: "[&_[data-slot=toast-icon]]:text-primary",
          destructive: "text-destructive [&_[data-slot=toast-icon]]:text-destructive"
        }

        element :icon, "mt-0.5 flex size-4 shrink-0 items-center justify-center [&_svg]:size-4"
        element :body, "flex min-w-0 flex-1 flex-col gap-1"
        element :title, "text-sm font-medium"
        element :description, "text-sm text-muted-foreground"
        element :action, "shrink-0 self-start"
        element :close, "shrink-0 self-start"
      end
    end
  end
end
