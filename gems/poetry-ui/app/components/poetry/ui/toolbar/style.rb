# frozen_string_literal: true

module Poetry
  module Ui
    module Toolbar
      # Utility-only (the Separator/Spinner rule): there is no upstream
      # look to be faithful to - the strip is a structural gap row;
      # data-slot=toolbar is the restyle seam for any theme that wants
      # chrome (border, background) on it.
      class Style < Poetry::Core::Style
        base "flex w-fit items-center gap-1"

        variant :orientation, {
          horizontal: "flex-row",
          vertical: "flex-col items-stretch"
        }
      end
    end
  end
end
