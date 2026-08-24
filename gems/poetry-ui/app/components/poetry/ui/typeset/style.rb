# frozen_string_literal: true

module Poetry
  module Ui
    module Typeset
      # The switch class only: the actual element rules live in the
      # app-owned typeset.css (copied at install). No cn-* name - the
      # artifact is deliberately outside the theme layer: one CSS file
      # the app owns.
      class Style < Poetry::Core::Style
        base "typeset"
      end
    end
  end
end
