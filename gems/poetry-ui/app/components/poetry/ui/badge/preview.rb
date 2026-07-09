# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(variant: :default) { "New" }
        end

        def secondary
          render_component(variant: :secondary) { "Draft" }
        end

        def destructive
          render_component(variant: :destructive) { "Failed" }
        end

        def outline
          render_component(variant: :outline) { "Beta" }
        end

        # The status vocabulary (Blocks v1.1): soft tints on the status
        # tokens - the axe walk holds every theme's treatment to AA here.
        def success
          render_component(variant: :success) { "Fulfilled" }
        end

        def warning
          render_component(variant: :warning) { "Processing" }
        end

        def info
          render_component(variant: :info) { "Syncing" }
        end
      end
    end
  end
end
