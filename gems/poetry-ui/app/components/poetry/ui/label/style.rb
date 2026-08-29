# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      # Re-expressed through the cn-* theme layer.
      class Style < Poetry::Core::Style
        base "cn-label flex items-center select-none peer-disabled:cursor-not-allowed " \
             "group-data-[disabled=true]:pointer-events-none"
      end
    end
  end
end
