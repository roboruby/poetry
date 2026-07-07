# frozen_string_literal: true

module Poetry
  module Ui
    module Deferred
      # The Deferred preview. The dummy loads no Turbo, so the frame stays
      # inert: what renders (and what the baseline captures) IS the
      # placeholder state - deterministic by construction. Live loading /
      # error / retry behavior is proven in poetry-core's deferred.test.js
      # and on the docs site's /deferred page.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(src: "/previews/activity")
        end

        def custom_placeholder
          render_component(src: "/previews/activity") do
            "Fetching the latest activity…"
          end
        end
      end
    end
  end
end
