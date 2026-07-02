# frozen_string_literal: true

module Poetry
  module Ui
    module Label
      # The Label preview - always tied to a control via for_id (the
      # component's whole contract), so the sidecar preview.html.erb renders
      # the label/input pair.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with(component: Component.new(for_id: "label-full-name"))
        end
      end
    end
  end
end
