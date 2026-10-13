# frozen_string_literal: true

module Poetry
  module Motion
    module Confetti
      # Confetti preview: a button that bursts on click.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do
            classes = "rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground"
            tag.button("Ship it", type: "button", class: classes)
          end
        end
      end
    end
  end
end
