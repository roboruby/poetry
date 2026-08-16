# frozen_string_literal: true

module Poetry
  module SimpleForm
    module Inputs
      class PasswordInput < Base
        private def poetry_as = :password
      end
    end
  end
end
