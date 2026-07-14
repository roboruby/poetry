# frozen_string_literal: true

module Poetry
  module Ui
    module SearchField
      # Utility-only: InputGroup + Input wear the chrome (the NumberField
      # composition - zero new theme CSS). The input element only
      # suppresses WebKit's native search affordances so poetry's clear
      # button is the single clear path.
      class Style < Poetry::Core::Style
        base "flex w-full flex-col"

        element :input, "[&::-webkit-search-cancel-button]:hidden " \
                        "[&::-webkit-search-decoration]:hidden"
      end
    end
  end
end
