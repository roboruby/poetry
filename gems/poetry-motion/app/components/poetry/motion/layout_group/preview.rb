# frozen_string_literal: true

module Poetry
  module Motion
    module LayoutGroup
      # Layout group preview: a segmented control whose highlight follows the choice.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(class: "inline-flex rounded-lg bg-muted p-1") do
            safe_join(%w[Day Week Month].map do |range|
              checked = range == "Week"
              tag.button(type: "button", class: "relative px-3 py-1 text-sm", "aria-pressed" => checked.to_s) do
                highlight = tag.span("data-layout-id" => "range", "data-slot" => "layout-group-item",
                                     "aria-hidden" => "true",
                                     class: "absolute inset-0 hidden rounded-md bg-background shadow-xs " \
                                            "in-aria-pressed:block")
                safe_join([highlight, tag.span(range, class: "relative")])
              end
            end)
          end
        end
      end
    end
  end
end
