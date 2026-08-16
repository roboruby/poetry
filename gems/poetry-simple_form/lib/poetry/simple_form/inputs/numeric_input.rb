# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # NumberField; poetry re-derives min/max/step from numericality, so
      # the shim passes nothing simple_form computed.
      class NumericInput < Base
        private def poetry_as = :number
      end
    end
  end
end
