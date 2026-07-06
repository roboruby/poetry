# frozen_string_literal: true

module Poetry
  module Ui
    module Item
      # Re-expressed through the cn-* theme layer (N11). The media variants
      # use upstream's cn-item-media-variant-* names. Upstream's unused
      # group/item-group marker stays dropped (compiled-CSS gate, N9 W1a).
      class Style < Poetry::Core::Style
        base "cn-item group/item flex w-full flex-wrap items-center transition-colors " \
             "duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] " \
             "focus-visible:ring-ring/50 [a]:transition-colors"

        variant :variant, {
          default: "cn-item-variant-default",
          outline: "cn-item-variant-outline",
          muted: "cn-item-variant-muted"
        }

        variant :size, {
          default: "cn-item-size-default",
          sm: "cn-item-size-sm",
          xs: "cn-item-size-xs"
        }

        element :media, "cn-item-media flex shrink-0 items-center justify-center " \
                        "[&_svg]:pointer-events-none"
        element :media_default, "cn-item-media-variant-default"
        element :media_icon, "cn-item-media-variant-icon"
        element :media_image, "cn-item-media-variant-image"
        element :content, "cn-item-content flex flex-1 flex-col [&+[data-slot=item-content]]:flex-none"
        element :title, "cn-item-title line-clamp-1 flex w-fit items-center"
        element :description, "cn-item-description line-clamp-2 font-normal [&>a]:underline " \
                              "[&>a]:underline-offset-4 [&>a:hover]:text-primary"
        element :actions, "cn-item-actions flex items-center"
        element :header, "cn-item-header flex basis-full items-center justify-between"
        element :footer, "cn-item-footer flex basis-full items-center justify-between"

        # The list wrapper + row separator (poetry_item_group / _separator).
        element :group, "cn-item-group flex w-full flex-col"
        element :separator, "cn-item-separator"
      end
    end
  end
end
