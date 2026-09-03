# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # Serves `as: :password`: a poetry Field wrapping a type=password
      # Input; the value never round-trips into the markup.
      class PasswordInput < Base
        private

        def poetry_as = :password
      end
    end
  end
end
