# frozen_string_literal: true

module Poetry
  module Ui
    module Attachment
      # The Attachment dictionary - shadcn new-york-v4 AI-chat set,
      # source-validated 2026-07-01 (Attachment). The
      # upload lifecycle is PURE CSS on group-data-[state=...] (idle
      # dashes the border, uploading/processing shimmer the title, error
      # tints destructive, in-flight images dim); media's icon/image
      # variant rides data-[variant] selectors in one dictionary string.
      class Style < Poetry::Core::Style
        base "group/attachment relative flex w-fit max-w-full min-w-0 shrink-0 flex-wrap rounded-xl border " \
             "bg-card text-card-foreground transition-colors focus-within:ring-1 focus-within:ring-ring/50 " \
             "has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 " \
             "data-[state=idle]:border-dashed"

        variant :size, {
          default: "gap-2 text-sm has-data-[slot=attachment-content]:px-2.5 " \
                   "has-data-[slot=attachment-content]:py-2 has-data-[slot=attachment-media]:p-2",
          sm: "gap-2.5 text-xs has-data-[slot=attachment-content]:px-2 " \
              "has-data-[slot=attachment-content]:py-1.5 has-data-[slot=attachment-media]:p-1.5",
          xs: "gap-1.5 rounded-lg text-xs has-data-[slot=attachment-content]:px-1.5 " \
              "has-data-[slot=attachment-content]:py-1 has-data-[slot=attachment-media]:p-1"
        }

        variant :orientation, {
          horizontal: "min-w-40 items-center",
          vertical: "w-24 flex-col has-data-[slot=attachment-content]:w-30"
        }

        element :media, "relative flex aspect-square w-10 shrink-0 items-center justify-center overflow-hidden " \
                        "rounded-lg bg-muted text-foreground group-data-[orientation=vertical]/attachment:w-full " \
                        "group-data-[size=sm]/attachment:w-8 group-data-[size=xs]/attachment:w-7 " \
                        "group-data-[size=xs]/attachment:rounded-md " \
                        "group-data-[state=error]/attachment:bg-destructive/10 " \
                        "group-data-[state=error]/attachment:text-destructive " \
                        "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! " \
                        "[&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 " \
                        "group-data-[orientation=vertical]/attachment:[&_svg:not([class*='size-'])]:size-6 " \
                        "group-data-[size=xs]/attachment:[&_svg:not([class*='size-'])]:size-3.5 " \
                        "data-[variant=image]:opacity-60 " \
                        "data-[variant=image]:group-data-[state=done]/attachment:opacity-100 " \
                        "data-[variant=image]:group-data-[state=idle]/attachment:opacity-100 " \
                        "data-[variant=image]:*:[img]:aspect-square data-[variant=image]:*:[img]:w-full " \
                        "data-[variant=image]:*:[img]:object-cover"

        element :content, "max-w-full min-w-0 flex-1 leading-tight group-data-[orientation=vertical]/attachment:px-1"

        element :title, "block max-w-full min-w-0 truncate font-medium " \
                        "group-data-[state=processing]/attachment:shimmer " \
                        "group-data-[state=uploading]/attachment:shimmer"

        element :description, "mt-0.5 block max-w-full min-w-0 truncate text-xs text-muted-foreground " \
                              "group-data-[state=error]/attachment:text-destructive/80"

        element :actions, "relative z-20 flex shrink-0 items-center " \
                          "group-data-[orientation=vertical]/attachment:absolute " \
                          "group-data-[orientation=vertical]/attachment:top-3 " \
                          "group-data-[orientation=vertical]/attachment:right-3 " \
                          "group-data-[orientation=vertical]/attachment:gap-1"

        element :trigger, "absolute inset-0 z-10 outline-none"

        element :group, "flex min-w-0 scroll-fade-x snap-x snap-mandatory scroll-px-1 scrollbar-none gap-3 " \
                        "overflow-x-auto overscroll-x-contain py-1 *:data-[slot=attachment]:flex-none " \
                        "*:data-[slot=attachment]:snap-start"
      end
    end
  end
end
