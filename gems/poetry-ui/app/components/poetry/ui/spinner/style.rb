# frozen_string_literal: true

module Poetry
  module Ui
    module Spinner
      # Style dictionary for the Spinner family: the loader glyph, spinning.
      class Style < Poetry::Core::Style
        base "size-4 animate-spin"
      end
    end
  end
end
