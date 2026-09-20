# frozen_string_literal: true

module Poetry
  module Ui
    module Separator
      # Style dictionary for the Separator family. The thickness/length
      # flips on data-horizontal / data-vertical, driven by the rendered
      # data-orientation.
      class Style < Poetry::Core::Style
        base "shrink-0 bg-border data-horizontal:h-px data-horizontal:w-full " \
             "data-vertical:w-px data-vertical:self-stretch"
      end
    end
  end
end
