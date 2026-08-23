# frozen_string_literal: true

module Poetry
  module Ui
    module Kbd
      # Re-expressed through the cn-* theme layer: the keyboard-key
      # chip's look (incl. the tooltip inversion) rides themes/default.css.
      class Style < Poetry::Core::Style
        base "cn-kbd pointer-events-none inline-flex items-center justify-center select-none"
      end
    end
  end
end
