# frozen_string_literal: true

module Poetry
  module Motion
    module WordRotate
      # Word rotate preview: a headline with a turning word.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(words: %w[faster safer together], class: "text-3xl font-semibold text-primary")
        end
      end
    end
  end
end
