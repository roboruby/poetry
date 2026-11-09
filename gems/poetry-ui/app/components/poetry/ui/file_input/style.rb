# frozen_string_literal: true

module Poetry
  module Ui
    module FileInput
      # Utility-only (the Separator/Spinner rule): the input variant wears
      # the Input component's own chrome; the dropzone is structural
      # utilities on semantic tokens, with the controllers' data-dragging /
      # data-drag-reject / data-drag-global / data-populated (on the ROOT)
      # driving the zone's states through group-data variants. data-slot
      # selectors are the restyle seam.
      class Style < Poetry::Core::Style
        base "group/file-input flex w-full min-w-0 flex-col gap-2"

        element :dropzone,
                "flex min-h-32 w-full cursor-pointer flex-col items-center justify-center gap-1.5 " \
                "rounded-lg border border-dashed border-input bg-transparent px-6 py-8 text-center " \
                "transition-colors outline-none hover:bg-accent/30 " \
                "has-focus-visible:border-ring has-focus-visible:ring-[3px] has-focus-visible:ring-ring/50 " \
                "group-data-[dragging]/file-input:border-primary " \
                "group-data-[dragging]/file-input:bg-accent/40 " \
                "group-data-[drag-reject]/file-input:border-destructive " \
                "group-data-[drag-reject]/file-input:bg-destructive/10"
        element :dropzone_disabled, "pointer-events-none cursor-not-allowed opacity-50"
        element :icon, "size-5 text-muted-foreground"
        element :prompt, "text-sm font-medium"
        element :hint, "text-xs text-muted-foreground"
        # The chips: one Attachment per file, full width, stacked.
        element :items, "flex flex-col gap-1.5 empty:hidden *:data-[slot=attachment]:w-full"
        element :errors, "flex flex-col gap-1 text-sm text-destructive empty:hidden"
        element :clear, "self-start text-sm font-medium text-muted-foreground underline-offset-4 " \
                        "hover:text-foreground hover:underline"
        # The full-window drop surface: no pointer events, so the drop
        # reaches the document the file-drop controller listens on.
        element :overlay, "pointer-events-none fixed inset-0 z-50 hidden items-center justify-center " \
                          "bg-background/80 backdrop-blur-sm group-data-[drag-global]/file-input:flex"
        element :overlay_prompt, "rounded-lg border-2 border-dashed border-primary px-10 py-8 text-lg " \
                                 "font-medium text-foreground"
      end
    end
  end
end
