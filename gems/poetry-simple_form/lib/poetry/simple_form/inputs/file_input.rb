# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      class FileInput < Base
        private def poetry_as = :file
      end
    end
  end
end
