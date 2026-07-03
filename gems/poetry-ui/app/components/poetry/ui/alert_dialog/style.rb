# frozen_string_literal: true

module Poetry
  module Ui
    module AlertDialog
      # The AlertDialog dictionary - shadcn new-york-v4 alert-dialog.tsx,
      # source-validated 2026-07-02 (see AlertDialog).
      # Ported like the parent Dialog: fixed/translate centering becomes the
      # top layer's m-auto, the overlay div becomes ::backdrop, and exit
      # animations wait for the presence hold (see the Sheet dictionary).
      # The source's group/has- selector gymnastics for media and size are
      # NOT ported as CSS - the component emits the *_with_media and
      # *_size_* elements below as explicit server-side conditionals.
      class Style < Poetry::Core::Style
        # open:grid, NOT grid (the Dialog's UA display:none lesson). The
        # size branches ride the stamped data-size, source-exact.
        element :content, "relative m-auto open:grid w-full max-w-[calc(100%-2rem)] gap-4 rounded-lg border " \
                          "bg-background p-6 text-foreground shadow-lg " \
                          "data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-lg " \
                          "backdrop:bg-black/50 data-[state=open]:animate-in data-[state=open]:fade-in-0 " \
                          "data-[state=open]:zoom-in-95"

        element :header, "grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center"
        element :header_with_media, "grid-rows-[auto_auto_1fr] gap-x-6"
        # default size: centered on mobile, left from sm (sm size stays
        # centered at every breakpoint - source).
        element :header_size_default, "sm:place-items-start sm:text-left"
        element :header_size_default_with_media, "sm:grid-rows-[auto_1fr]"

        element :media, "mb-2 inline-flex size-16 items-center justify-center rounded-md bg-muted " \
                        "*:[svg:not([class*='size-'])]:size-8"
        element :media_size_default, "sm:row-span-2"

        element :title, "text-lg font-semibold"
        element :title_beside_media, "sm:col-start-2"

        element :description, "text-sm text-muted-foreground"

        element :footer, "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
        # sm size: the compact 2-col grid footer (source).
        element :footer_size_sm, "grid grid-cols-2"
      end
    end
  end
end
