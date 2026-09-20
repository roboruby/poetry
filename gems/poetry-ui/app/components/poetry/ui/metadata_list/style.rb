# frozen_string_literal: true

module Poetry
  module Ui
    module MetadataList
      # Utility-only (the Separator/Spinner rule): no upstream cn hook
      # exists for a description list, so the surface is structural
      # utilities on semantic tokens; data-slot selectors are the restyle
      # seam. The horizontal orientation restyles the ITEMS from the root
      # (a root descendant utility outranks the item's own class), so one
      # attribute flip re-lays the whole sheet.
      class Style < Poetry::Core::Style
        base "grid gap-x-8 gap-y-4"

        variant :columns, {
          one: "grid-cols-1",
          two: "grid-cols-1 sm:grid-cols-2",
          three: "grid-cols-1 sm:grid-cols-3"
        }

        variant :orientation, {
          vertical: "",
          horizontal: "[&_[data-slot=metadata-list-item]]:grid " \
                      "[&_[data-slot=metadata-list-item]]:grid-cols-[minmax(0,8rem)_1fr] " \
                      "[&_[data-slot=metadata-list-item]]:items-baseline " \
                      "[&_[data-slot=metadata-list-item]]:gap-x-4"
        }

        element :item, "flex min-w-0 flex-col gap-1"
        element :label, "text-sm text-muted-foreground"
        element :value, "min-w-0 text-sm font-medium break-words"
      end
    end
  end
end
