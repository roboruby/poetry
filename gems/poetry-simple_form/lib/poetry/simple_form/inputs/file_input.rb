# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # Serves `as: :file`: a poetry Field wrapping the FileInput
      # component (the native file control in poetry chrome; input_html
      # options such as variant:/multiple: pass through).
      class FileInput < Base
        private def poetry_as = :file
      end
    end
  end
end
