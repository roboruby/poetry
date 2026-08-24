# frozen_string_literal: true

module Poetry
  module Ui
    module Skeleton
      # Style dictionary for the Skeleton family: the pulse is the
      # mechanism (inline), the box treatment is the theme's.
      class Style < Poetry::Core::Style
        base "cn-skeleton animate-pulse"
      end
    end
  end
end
