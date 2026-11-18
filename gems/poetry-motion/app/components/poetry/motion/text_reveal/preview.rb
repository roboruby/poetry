# frozen_string_literal: true

module Poetry
  module Motion
    module TextReveal
      # Text reveal previews: a statement and a heading.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(text: "Poetry renders the finished page on the server, and motion is only ever " \
                                 "the way there.", class: "text-3xl font-semibold")
        end

        def heading
          render_component(text: "Every word arrives in order.", tag: :h2, class: "text-4xl font-bold")
        end
      end
    end
  end
end
