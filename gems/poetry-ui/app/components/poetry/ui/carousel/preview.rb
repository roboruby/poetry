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

        # The spacing trio (track_classes + per-item pl/-scroll-ml): the
        # track margin, the gutter padding, and the snap scroll-margin
        # move together - this preview pins the tightened geometry.
        def spacing
          render_component(label: "Tight gallery", track_classes: "-ml-1", class: "mx-14 w-80") do |carousel|
            5.times do |n|
              carousel.with_item(classes: "basis-1/3 pl-1 -scroll-ml-1") do
                tag.div((n + 1).to_s,
                        class: "flex aspect-square items-center justify-center rounded-md border bg-muted text-xl")
              end
            end
          end
        end

        # Vertical stack, upstream's orientation proportions: fixed-height
        # slides (the auto-height track cannot resolve percentage bases),
        # two visible, enough roster to page. The -top-12/-bottom-12
        # controls need gutter room (my-14).
        def vertical
          render_component(label: "Release milestones", orientation: :vertical,
                           class: "mx-auto my-14 grid h-64 w-52") do |carousel|
            6.times do |n|
              carousel.with_item do
                tag.div("Week #{n + 1}",
                        class: "flex h-28 items-center justify-center rounded-md border bg-muted text-sm font-semibold")
              end
            end
          end
        end
      end
    end
  end
end
