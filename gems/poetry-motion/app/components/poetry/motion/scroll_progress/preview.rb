# frozen_string_literal: true

module Poetry
  module Motion
    module ScrollProgress
      # Scroll progress preview: an inline bar, empty as the server renders it.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(position: :inline)
        end
      end
    end
  end
end
