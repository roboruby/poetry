# frozen_string_literal: true

module Poetry
  module Ui
    module NumberField
      # Deliberately near-empty (the composition decision): the
      # group wears InputGroup's chrome, the control wears Input's, the
      # steppers wear Button's - zero new theme CSS. The root only stacks.
      class Style < Poetry::Core::Style
        base "flex w-full flex-col"
      end
    end
  end
end
