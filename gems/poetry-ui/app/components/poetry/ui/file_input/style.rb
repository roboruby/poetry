# frozen_string_literal: true

module Poetry
  module Ui
    module FileInput
      # Utility-only (the Separator/Spinner rule): the input variant wears
      # the Input component's own chrome; the dropzone is structural
      # utilities on semantic tokens, with the controller's data-dragging /
      # data-populated (on the ROOT) driving the zone's states through
      # group-data variants. data-slot selectors are the restyle seam.
      class Style < Poetry::Core::Style
        base "group/file-input flex w-full min-w-0 flex-col gap-2"

        element :dropzone,
                "flex min-h-32 w-full cursor-pointer flex-col items-center justify-center gap-1.5 " \
                "rounded-lg border border-dashed border-input bg-transparent px-6 py-8 text-center " \
                "transition-colors outline-none hover:bg-accent/30 " \
                "has-focus-visible:border-ring has-focus-visible:ring-[3px] has-focus-visible:ring-ring/50 " \
                "group-data-[dragging]/file-input:border-primary " \
                "group-data-[dragging]/file-input:bg-accent/40"
        element :dropzone_disabled, "pointer-events-none cursor-not-allowed opacity-50"
        element :icon, "size-5 text-muted-foreground"
        element :prompt, "text-sm font-medium"
        element :hint, "text-xs text-muted-foreground"
        element :list, "flex flex-col gap-1 text-sm empty:hidden " \
                       "[&>li]:flex [&>li]:items-baseline [&>li]:justify-between [&>li]:gap-4 " \
                       "[&>li]:rounded-md [&>li]:border [&>li]:px-3 [&>li]:py-1.5 " \
                       "[&_[data-slot=file-input-item-size]]:text-xs " \
                       "[&_[data-slot=file-input-item-size]]:text-muted-foreground"
        element :clear, "self-start text-sm font-medium text-muted-foreground underline-offset-4 " \
                        "hover:text-foreground hover:underline"
      end
    end
  end
end
