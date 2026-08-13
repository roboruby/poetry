# frozen_string_literal: true

module Poetry
  module Ui
    module Autocomplete
      # The Autocomplete wears the Combobox/Command visual language (the
      # popup shell and item treatments are the same family upstream);
      # no autocomplete-specific theme rules exist in the upstream
      # dictionaries, so every class here is already-emitted vocabulary.
      class Style < Poetry::Core::Style
        base "relative"

        element :content, "cn-combobox-content cn-menu-translucent z-50 w-(--anchor-width) " \
                          "origin-(--transform-origin) outline-hidden"
      end
    end
  end
end
