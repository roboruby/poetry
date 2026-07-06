# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      # Re-expressed through the cn-* theme layer (N11).
      class Style < Poetry::Core::Style
        base "cn-label flex items-center select-none peer-disabled:cursor-not-allowed"
      end
    end
  end
end
