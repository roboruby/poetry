# frozen_string_literal: true

module Poetry
  module Motion
    module SpotlightCard
      # Spotlight card preview: a plain surface.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(class: "max-w-sm") do
            tag.div(class: "rounded-xl border bg-card/80 p-6 text-card-foreground") do
              safe_join([tag.h3("Follow the light", class: "font-semibold"),
                         tag.p("A glow tracks the pointer.", class: "text-sm text-muted-foreground")])
            end
          end
        end
      end
    end
  end
end
