# frozen_string_literal: true

module Poetry
  module Ui
    module Skeleton
      # Re-expressed through the cn-* theme layer: the pulse is the
      # mechanism (inline), the box treatment is the theme's.
      class Style < Poetry::Core::Style
        base "cn-skeleton animate-pulse"
      end
    end
  end
end
