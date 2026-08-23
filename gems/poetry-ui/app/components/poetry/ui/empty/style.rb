# frozen_string_literal: true

module Poetry
  module Ui
    module Empty
      # Re-expressed through the cn-* theme layer. The title wears
      # cn-font-heading (upstream parity): a no-op until a theme
      # defines --font-heading - the sanctioned heading-font hook.
      class Style < Poetry::Core::Style
        base "cn-empty flex w-full min-w-0 flex-1 flex-col items-center justify-center " \
             "text-center text-balance"

        element :header, "cn-empty-header flex max-w-sm flex-col items-center"
        # The media wrapper splits shared chrome from its two variants
        # (default: transparent; icon: the rounded muted tile).
        element :media, "cn-empty-media flex shrink-0 items-center justify-center " \
                        "[&_svg]:pointer-events-none [&_svg]:shrink-0"
        element :media_default, "cn-empty-media-default"
        element :media_icon, "cn-empty-media-icon"
        element :title, "cn-empty-title cn-font-heading"
        element :description, "cn-empty-description text-muted-foreground [&>a]:underline " \
                              "[&>a]:underline-offset-4 [&>a:hover]:text-primary"
        element :content, "cn-empty-content flex w-full max-w-sm min-w-0 flex-col items-center text-balance"
      end
    end
  end
end
