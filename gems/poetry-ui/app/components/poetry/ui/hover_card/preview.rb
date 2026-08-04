# frozen_string_literal: true

module Poetry
  module Ui
    module HoverCard
      # The HoverCard preview matrix: the shadcn hover-card-demo profile
      # preview (the @nextjs card, w-80 override), the server-pinned open
      # state, a placement sample, and custom delays. Every preview's card
      # content is reachable at the trigger's href - the
      # reachable-elsewhere audit runs against real destinations.
      class Preview < Poetry::Core::Preview::Base
        # The hover-card-demo port: a real profile link enriched with the
        # profile preview. The trigger text is the link; the card is pure
        # enhancement over navigation.
        def default
          profile_example
        end

        # Server-pinned open (controllable-state; the controller
        # reconciles the layer + the tabindex strip on connect).
        def open
          profile_example(open: true)
        end

        # Placement sample (data-side re-resolves live on collision).
        def side_right
          render_component(side: :right, align: :start) do |card|
            card.with_trigger(href: "https://github.com/vercel") { "@vercel" }
            "Develop. Preview. Ship."
          end
        end

        # Snappier delays for preview-dense surfaces (the docs recommend
        # keeping open_delay >= ~300ms - accidental opens while mousing
        # across text feel broken).
        def fast
          render_component(open_delay: 300, close_delay: 150) do |card|
            card.with_trigger(href: "https://github.com/rails") { "@rails" }
            "Ruby on Rails - the full-stack web framework."
          end
        end

        private

        def profile_example(**options)
          render_component(content_class: "w-80", **options) do |card|
            card.with_trigger(href: "https://github.com/nextjs", class: "text-sm font-medium underline-offset-4 hover:underline") { "@nextjs" }
            # No text size here - the card's type scale is theme-owned
            # (.cn-hover-card-content; mira/lyra run text-xs/relaxed).
            tag.div(class: "flex flex-col gap-1") do
              tag.h4("@nextjs", class: "font-semibold") +
                tag.p("The React Framework - created and maintained by @vercel.") +
                tag.div("Joined December 2021", class: "text-xs text-muted-foreground")
            end
          end
        end
      end
    end
  end
end
