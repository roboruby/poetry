# frozen_string_literal: true

module Poetry
  module Ui
    module Sheet
      # The Sheet dictionary - shadcn new-york-v4 sheet.tsx, source-validated
      # 2026-07-02 (see Sheet). Ported like the parent
      # Dialog: shadcn's fixed/inset positioning becomes top-layer margins on
      # the native <dialog> (m-0 + the side's auto margin replace Dialog's
      # m-auto centering); the separate SheetOverlay div becomes ::backdrop.
      # Exit animations (data-closed:animate-out slide-out-to-*,
      # duration-300) are NOT ported yet: the shared dialog controller closes
      # instantly, and a slide-out needs the presence hold (the contract's
      # open question) - land it with the controller change, never before.
      class Style < Poetry::Core::Style
        # open:flex, NOT flex: a bare display class would defeat the UA's
        # dialog:not([open]) { display: none } (the Dialog's 2026-07-01
        # browser-pass lesson, inherited here).
        element :content, "relative m-0 open:flex w-full flex-col gap-4 bg-background text-foreground shadow-lg " \
                          "transition ease-in-out data-open:animate-in data-open:duration-500 " \
                          "backdrop:bg-black/50"

        # The side branches, source-exact minus fixed/inset (top layer =
        # margins; max-w-none / max-h-none clear the UA's top-layer caps so
        # the sheet reaches edge to edge). Applied to :content by the
        # component via Style.side - the resolver renders variants only at
        # the dictionary root, and the Sheet's root wrapper is non-visual.
        variant :side, {
          top: "mb-auto h-auto w-full max-w-none border-b data-open:slide-in-from-top",
          right: "ml-auto h-full max-h-none w-3/4 border-l data-open:slide-in-from-right sm:max-w-sm",
          bottom: "mt-auto h-auto w-full max-w-none border-t data-open:slide-in-from-bottom",
          left: "mr-auto h-full max-h-none w-3/4 border-r data-open:slide-in-from-left sm:max-w-sm"
        }

        element :header, "flex flex-col gap-1.5 p-4"
        element :title, "font-semibold text-foreground"
        element :description, "text-sm text-muted-foreground"
        # mt-auto pins the footer to the bottom edge (source).
        element :footer, "mt-auto flex flex-col gap-2 p-4"
        element :close, "absolute top-4 right-4"

        # The side's edge classes for the <dialog> element.
        def self.side(value)
          resolver.variants.fetch(:side).fetch(value.to_sym)
        end
      end
    end
  end
end
