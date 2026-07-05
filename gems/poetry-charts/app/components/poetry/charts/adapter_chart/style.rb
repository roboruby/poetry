# frozen_string_literal: true

module Poetry
  module Charts
    module AdapterChart
      # The mount fills the Container's aspect box; the engine owns
      # everything inside it.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :mount, "size-full"
      end
    end
  end
end
