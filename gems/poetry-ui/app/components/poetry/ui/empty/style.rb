# frozen_string_literal: true

module Poetry
  module Ui
    module Empty
      # shadcn Empty (base-vega), source-exact - except the title's
      # cn-font-heading, a theme-layer indirection class the vendored CSS
      # does not define yet (dropped like pagination's cn-rtl-flip; the
      # cn-* theme layer is its own later milestone).
      class Style < Poetry::Core::Style
        base "flex w-full min-w-0 flex-1 flex-col items-center justify-center gap-4 rounded-lg " \
             "border-dashed p-12 text-center text-balance"

        element :header, "flex max-w-sm flex-col items-center gap-2"
        # The media wrapper splits shared chrome from its two variants
        # (default: transparent; icon: the rounded muted tile).
        element :media, "mb-2 flex shrink-0 items-center justify-center " \
                        "[&_svg]:pointer-events-none [&_svg]:shrink-0"
        element :media_default, "bg-transparent"
        element :media_icon, "flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted " \
                             "text-foreground [&_svg:not([class*='size-'])]:size-6"
        element :title, "text-lg font-medium tracking-tight"
        element :description, "text-sm/relaxed text-muted-foreground [&>a]:underline " \
                              "[&>a]:underline-offset-4 [&>a:hover]:text-primary"
        element :content, "flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance"
      end
    end
  end
end
