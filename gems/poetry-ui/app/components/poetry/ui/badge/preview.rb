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
      end
    end
  end
end
