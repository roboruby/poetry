# frozen_string_literal: true

module Poetry
  module Ui
    module Link
      # Re-expressed through the cn-* theme layer (N11). No upstream
      # counterpart (shadcn has no Link) - the split follows the category
      # rule: layout/behavior inline, color/decoration/focus ring themed.
      class Style < Poetry::Core::Style
        base "cn-link inline-flex items-center outline-none transition-colors"

        variant :underline, {
          hover: "cn-link-underline-hover",
          always: "cn-link-underline-always",
          none: "cn-link-underline-none"
        }
      end
    end
  end
end
