# frozen_string_literal: true

module Poetry
  module Motion
    module Parallax
      # Parallax preview: a decorative panel at rest.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(distance: 100, class: "max-w-md") do
            tag.div("Drifts as you scroll", class: "rounded-xl border bg-muted p-12 text-center text-sm font-medium")
          end
        end
      end
    end
  end
end
