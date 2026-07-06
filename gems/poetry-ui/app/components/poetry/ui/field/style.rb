# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      # Re-expressed through the cn-* theme layer (N11). Poetry's Field is
      # its own small shape (grid + hint + error); the cn names borrow
      # upstream's vocabulary where semantics align (:hint wears
      # cn-field-description - the style hook tracks upstream naming, the
      # data-slot stays poetry's).
      class Style < Poetry::Core::Style
        base "cn-field grid"

        element :hint, "cn-field-description"
        element :error, "cn-field-error"
      end
    end
  end
end
