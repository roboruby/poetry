# frozen_string_literal: true

module Poetry
  module Ui
    module Skeleton
      # shadcn Skeleton (base-vega), source-exact: a pulsing placeholder box.
      class Style < Poetry::Core::Style
        base "animate-pulse rounded-md bg-muted"
      end
    end
  end
end
