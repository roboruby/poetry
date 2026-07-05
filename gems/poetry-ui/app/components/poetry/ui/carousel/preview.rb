# frozen_string_literal: true

module Poetry
  module Ui
    module Carousel
      # The Carousel preview: full-width slides and a multi-slide strip.
      # The -left-12/-right-12 controls need gutter room (px-14).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Featured artwork", class: "mx-14 w-64") do |carousel|
            3.times do |n|
              carousel.with_item do
                tag.div("Slide #{n + 1}",
                        class: "flex aspect-square items-center justify-center rounded-md border bg-muted text-2xl")
              end
            end
          end
        end

        def strip
          render_component(label: "Related items", class: "mx-14 w-96") do |carousel|
            6.times do |n|
              carousel.with_item(classes: "basis-1/3") do
                tag.div((n + 1).to_s, class: "flex h-24 items-center justify-center rounded-md border bg-muted")
              end
            end
          end
        end
      end
    end
  end
end
