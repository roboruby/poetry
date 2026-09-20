# frozen_string_literal: true

module Poetry
  module Ui
    module AspectRatio
      # Style dictionary for the AspectRatio family: aspect-(--ratio) reads
      # the --ratio custom property the component writes inline.
      class Style < Poetry::Core::Style
        base "relative aspect-(--ratio)"
      end
    end
  end
end
