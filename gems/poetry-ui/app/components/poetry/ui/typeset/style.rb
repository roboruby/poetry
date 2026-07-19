# frozen_string_literal: true

module Poetry
  module Ui
    module Typeset
      # The switch class only: the actual element rules live in the
      # app-owned typeset.css (copied at install, upstream-verbatim body).
      # No cn-* name - the artifact is deliberately outside the theme layer,
      # exactly as upstream ships it ("one CSS file you own").
      class Style < Poetry::Core::Style
        base "typeset"
      end
    end
  end
end
