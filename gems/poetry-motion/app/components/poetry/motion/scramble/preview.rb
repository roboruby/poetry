# frozen_string_literal: true

module Poetry
  module Motion
    module Scramble
      # Scramble preview: a monospace label.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(text: "ACCESS GRANTED", class: "font-mono text-2xl font-semibold")
        end
      end
    end
  end
end
