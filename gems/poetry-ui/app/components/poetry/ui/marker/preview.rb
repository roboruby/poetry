# frozen_string_literal: true

module Poetry
  module Ui
    module Marker
      # The Marker preview matrix.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component { "Assistant is thinking" }
        end

        def separator
          render_component(variant: :separator) { "Yesterday" }
        end

        def border
          render_component(variant: :border) { "Earlier in this thread" }
        end

        def with_icon
          render_component do |marker|
            marker.with_icon(name: :sparkles)
            "Generating a summary"
          end
        end

        def announcing_status
          render_component(announce: :status) { "Searching the web…" }
        end
      end
    end
  end
end
