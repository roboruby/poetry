# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      # The horizontal boolean Field (poetry's f.input boolean story);
      # input_html: { switch: true } opts into the setting-row Switch.
      class BooleanInput < Base
        private def poetry_as = :boolean
      end
    end
  end
end
