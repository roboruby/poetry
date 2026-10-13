# frozen_string_literal: true

module Poetry
  module Motion
    module Particles
      # Particles preview: linked dots behind a heading.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(link: 90, class: "flex h-64 items-center justify-center rounded-xl border text-primary") do
            tag.h2("Finished on the server", class: "text-2xl font-semibold text-foreground")
          end
        end
      end
    end
  end
end
