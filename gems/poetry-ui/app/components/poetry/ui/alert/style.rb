# frozen_string_literal: true

module Poetry
  module Ui
    module Alert
      # Re-expressed through the cn-* theme layer: entries carry the
      # stable names + the structural inline set; themes/default.css holds
      # the design (the grid treatment, variants).
      class Style < Poetry::Core::Style
        base "cn-alert relative w-full group/alert"

        variant :variant, {
          default: "cn-alert-variant-default",
          destructive: "cn-alert-variant-destructive"
        }

        element :title, "cn-alert-title [&_a]:hover:text-foreground [&_a]:underline [&_a]:underline-offset-3"
        element :action, "cn-alert-action"
        element :description, "cn-alert-description [&_a]:hover:text-foreground [&_a]:underline " \
                              "[&_a]:underline-offset-3"
      end
    end
  end
end
