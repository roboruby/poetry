# frozen_string_literal: true

module Poetry
  module Ui
    module Citation
      # The chip is a Badge, so the themes dress it. What is here sets it
      # in a line of prose: on the baseline, numerals of one width, and no
      # underline when the prose around it styles links. It carries no
      # margin: the space before it is the text's.
      class Style < Poetry::Core::Style
        base "px-1.5 align-baseline tabular-nums no-underline"
      end
    end
  end
end
