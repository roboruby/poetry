# frozen_string_literal: true

module Poetry
  module Ui
    module Spinner
      # shadcn Spinner (base-vega), source-exact: the loader glyph, spinning.
      class Style < Poetry::Core::Style
        base "size-4 animate-spin"
      end
    end
  end
end
