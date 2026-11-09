# frozen_string_literal: true

module Poetry
  module Motion
    module Magnetic
      # Magnetic preview: a call to action.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(strength: 10) do
            classes = "rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground"
            tag.button("Get started", type: "button", class: classes)
          end
        end
      end
    end
  end
end
