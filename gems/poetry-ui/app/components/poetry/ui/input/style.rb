# frozen_string_literal: true

module Poetry
  module Ui
    module Input
      # Re-expressed through the cn-* theme layer (N11): the field chrome
      # (border, ring, invalid, dark treatments) rides themes/default.css.
      class Style < Poetry::Core::Style
        base "cn-input w-full min-w-0 outline-none placeholder:text-muted-foreground " \
             "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
      end
    end
  end
end
