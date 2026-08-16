# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      class TextInput < Base
        private def poetry_as = :text
      end
    end
  end
end
