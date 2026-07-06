# frozen_string_literal: true

module Poetry
  module Ui
    module Attachment
      # Re-expressed through the cn-* theme layer (N11). The upload
      # lifecycle stays PURE CSS and INLINE per upstream's own split (idle
      # dashes, error tints, the in-flight image dim) - it is coupled to
      # the data-[upload-state] machine; sizes/orientation/surface ride the
      # theme. w-fit moved theme-side WITH the vertical w-24 (split-side).
      class Style < Poetry::Core::Style
        base "cn-attachment group/attachment relative flex max-w-full min-w-0 shrink-0 flex-wrap border " \
             "bg-card text-card-foreground transition-colors " \
             "has-[>a,>button]:hover:bg-muted/50 data-[upload-state=error]:border-destructive/30 " \
             "data-[upload-state=idle]:border-dashed"

        variant :size, {
          default: "cn-attachment-size-default",
          sm: "cn-attachment-size-sm",
          xs: "cn-attachment-size-xs"
        }

        variant :orientation, {
          horizontal: "cn-attachment-orientation-horizontal items-center",
          vertical: "cn-attachment-orientation-vertical flex-col"
        }

        element :media, "cn-attachment-media relative flex aspect-square shrink-0 items-center " \
                        "justify-center overflow-hidden " \
                        "group-data-[upload-state=error]/attachment:bg-destructive/10 " \
                        "group-data-[upload-state=error]/attachment:text-destructive " \
                        "group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! " \
                        "[&_svg]:pointer-events-none " \
                        "data-[variant=image]:opacity-60 " \
                        "data-[variant=image]:group-data-[upload-state=done]/attachment:opacity-100 " \
                        "data-[variant=image]:group-data-[upload-state=idle]/attachment:opacity-100 " \
                        "data-[variant=image]:*:[img]:aspect-square data-[variant=image]:*:[img]:w-full " \
                        "data-[variant=image]:*:[img]:object-cover"

        element :content, "cn-attachment-content max-w-full min-w-0 flex-1"

        element :title, "cn-attachment-title block max-w-full min-w-0 truncate " \
                        "group-data-[upload-state=processing]/attachment:shimmer " \
                        "group-data-[upload-state=uploading]/attachment:shimmer"

        element :description, "cn-attachment-description block max-w-full min-w-0 truncate " \
                              "group-data-[upload-state=error]/attachment:text-destructive/80"

        element :actions, "relative z-20 flex shrink-0 items-center " \
                          "group-data-[orientation=vertical]/attachment:absolute " \
                          "group-data-[orientation=vertical]/attachment:top-3 " \
                          "group-data-[orientation=vertical]/attachment:right-3 " \
                          "group-data-[orientation=vertical]/attachment:gap-1"

        element :trigger, "absolute inset-0 z-10 outline-none"

        element :group, "cn-attachment-group flex min-w-0 scroll-fade-x snap-x snap-mandatory " \
                        "scrollbar-none overflow-x-auto overscroll-x-contain " \
                        "*:data-[slot=attachment]:flex-none *:data-[slot=attachment]:snap-start"
      end
    end
  end
end
