# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # Re-expressed through the cn-* theme layer (N11): the chrome rides
      # poetry-named rules (own component - no upstream cn vocabulary).
      class Style < Poetry::Core::Style
        base "w-full"

        element :toolbar, "cn-data-table-toolbar flex items-center"
        element :container, "cn-data-table-container overflow-hidden"
        element :footer, "cn-data-table-footer"
        element :empty, "cn-data-table-empty"
      end
    end
  end
end
