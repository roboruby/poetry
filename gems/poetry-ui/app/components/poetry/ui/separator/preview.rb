# frozen_string_literal: true

module Poetry
  module Ui
    module Separator
      # The Separator preview: a decorative horizontal rule, and a semantic
      # vertical divider (role=separator).
      class Preview < Poetry::Core::Preview::Base
        def horizontal
          render_component(class: "my-2")
        end

        def vertical_semantic
          render_component(orientation: :vertical, decorative: false, class: "h-8")
        end
      end
    end
  end
end
