# frozen_string_literal: true

module Poetry
  module Motion
    module SharedElement
      # Shared element preview: the card half of a card-to-detail morph.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(name: "product-42", class: "max-w-xs") do
            tag.div(class: "rounded-xl border bg-card p-6 text-card-foreground shadow-sm") do
              safe_join([tag.h3("Field notebook", class: "font-semibold"), tag.p("$24", class: "text-sm")])
            end
          end
        end
      end
    end
  end
end
