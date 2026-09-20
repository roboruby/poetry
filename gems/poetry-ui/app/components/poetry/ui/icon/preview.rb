# frozen_string_literal: true

module Poetry
  module Ui
    module Icon
      class Preview < Poetry::Core::Preview::Base
        def decorative
          render_component(name: :plus)
        end

        def standalone_labeled
          render_component(name: :trash, label: "Delete")
        end

        def chevron
          render_component(name: :"chevron-right")
        end
      end
    end
  end
end
