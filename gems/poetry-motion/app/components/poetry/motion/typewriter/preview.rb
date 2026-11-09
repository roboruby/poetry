# frozen_string_literal: true

module Poetry
  module Motion
    module Typewriter
      # Typewriter preview: a headline line.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(text: "Ship the finished page first.", class: "text-2xl font-semibold")
        end
      end
    end
  end
end
