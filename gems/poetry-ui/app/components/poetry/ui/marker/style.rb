# frozen_string_literal: true

module Poetry
  module Ui
    module Marker
      # Re-expressed through the cn-* theme layer (N11). The separator
      # lines stay ::before/::after pseudo-elements (AT never sees them) -
      # now in the variant theme rule.
      class Style < Poetry::Core::Style
        base "cn-marker group/marker relative flex w-full items-center"

        variant :variant, {
          default: "",
          separator: "cn-marker-variant-separator",
          border: "cn-marker-variant-border"
        }

        element :icon, "cn-marker-icon shrink-0"

        element :content, "cn-marker-content min-w-0 wrap-break-word"
      end
    end
  end
end
