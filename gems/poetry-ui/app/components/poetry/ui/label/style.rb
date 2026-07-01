# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      class Style < Poetry::Core::Style
        base "flex select-none items-center gap-2 text-sm font-medium leading-none " \
             "peer-disabled:cursor-not-allowed peer-disabled:opacity-50"
      end
    end
  end
end
