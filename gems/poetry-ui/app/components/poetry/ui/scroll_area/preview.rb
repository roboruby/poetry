# frozen_string_literal: true

module Poetry
  module Ui
    module ScrollArea
      # The ScrollArea preview: a vertical tag list and a horizontal strip -
      # both overflow so the themed native scrollbars actually show.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Tags", class: "h-72 w-48 rounded-md border") do
            tag.div(class: "p-4") do
              safe_join([
                          tag.h4("Tags", class: "mb-4 text-sm leading-none font-medium"),
                          *(1..30).map do |n|
                            tag.div("v1.2.0-beta.#{n}", class: "border-b py-2 text-sm last:border-0")
                          end
                        ])
            end
          end
        end

        def horizontal
          render_component(label: "Artwork strip", class: "w-96 rounded-md border") do
            tag.div(class: "flex w-max gap-4 p-4") do
              safe_join((1..8).map do |n|
                tag.div("Artwork #{n}",
                        class: "flex h-32 w-40 shrink-0 items-center justify-center rounded-md bg-muted text-sm")
              end)
            end
          end
        end
      end
    end
  end
end
