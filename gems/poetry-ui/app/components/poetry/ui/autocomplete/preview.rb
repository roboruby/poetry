# frozen_string_literal: true

module Poetry
  module Ui
    module Autocomplete
      # The Autocomplete matrix: the closed hero, the server-rendered open
      # state with a highlight (the contract carrier for data-open /
      # data-highlighted), a value-override item, and the empty state.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(name: "tag", placeholder: "e.g. feature", label: "Search tags",
                           class: "w-64") do |auto|
            auto.with_item(label: "feature")
            auto.with_item(label: "fix")
            auto.with_item(label: "docs")
            auto.with_item(label: "internal")
            auto.with_item(label: "mobile", disabled: true)
          end
        end

        # Server-rendered open + highlighted (the states the contract holds).
        def open_and_highlighted
          render_component(name: "city", value: "sp", open: true, label: "City",
                           class: "w-64") do |auto|
            auto.with_item(label: "Springfield", highlighted: true)
            auto.with_item(label: "Spokane")
            auto.with_item(label: "São Paulo", value: "Sao Paulo")
          end
        end

        # No items at all: the empty message is the whole popup.
        def empty_state
          render_component(name: "search", open: true, label: "Search", open_on_focus: false,
                           empty_text: "Nothing matches.", class: "w-64")
        end
      end
    end
  end
end
