# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      class Style < Poetry::Core::Style
        base "grid gap-2"

        element :hint, "text-sm text-muted-foreground"
        element :error, "text-sm font-medium text-destructive"
      end
    end
  end
end
