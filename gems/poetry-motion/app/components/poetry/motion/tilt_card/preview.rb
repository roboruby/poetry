# frozen_string_literal: true

module Poetry
  module Motion
    module TiltCard
      # Tilt card previews: a plain surface and a stronger lean.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(class: "max-w-sm") { surface("Hover me", "The card leans toward the pointer.") }
        end

        def strong
          render_component(max: 16, spring: :bouncy, class: "max-w-sm") { surface("A stronger lean", "max: 16") }
        end

        private

        def surface(title, body)
          tag.div(class: "rounded-xl border bg-card p-6 text-card-foreground shadow-sm") do
            safe_join([tag.h3(title, class: "font-semibold"), tag.p(body, class: "text-sm text-muted-foreground")])
          end
        end
      end
    end
  end
end
