# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # shadcn DataTable chrome (base-vega demo), source-exact: the toolbar
      # row, the bordered table container, and the No-results cell. The table
      # itself is the W1 Table dictionary; the sort affordance is the ghost
      # Button.
      class Style < Poetry::Core::Style
        base "w-full"

        element :toolbar, "flex items-center py-4"
        element :container, "overflow-hidden rounded-md border"
        element :footer, "py-4"
        element :empty, "h-24 text-center"
      end
    end
  end
end
