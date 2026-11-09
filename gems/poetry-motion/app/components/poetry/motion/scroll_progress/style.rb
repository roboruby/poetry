# frozen_string_literal: true

module Poetry
  module Motion
    module ScrollProgress
      # The bar's classes; its fill lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "pointer-events-none h-1 w-full bg-primary data-[position=top]:fixed data-[position=top]:inset-x-0 " \
             "data-[position=top]:top-0 data-[position=top]:z-50 data-[position=bottom]:fixed " \
             "data-[position=bottom]:inset-x-0 data-[position=bottom]:bottom-0 data-[position=bottom]:z-50"
      end
    end
  end
end
