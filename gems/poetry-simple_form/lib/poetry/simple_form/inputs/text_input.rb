# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # Serves `as: :text`: a poetry Field wrapping the Textarea
      # component.
      class TextInput < Base
        private

        # Renders as Poetry's text area field.
        def poetry_as = :text
      end
    end
  end
end
