# frozen_string_literal: true

module Poetry
  module Ui
    module Progress
      # Re-expressed through the cn-* theme layer (N11). The root keeps no
      # cn name (its whole poetry surface is structural; upstream's
      # cn-progress-root returns with content in a future theme).
      class Style < Poetry::Core::Style
        base "flex flex-wrap gap-3"

        element :track, "cn-progress-track relative flex w-full items-center overflow-x-hidden"
        element :indicator, "cn-progress-indicator h-full transition-all"
        element :label, "cn-progress-label"
        element :value, "cn-progress-value"
      end
    end
  end
end
