# frozen_string_literal: true

module Poetry
  module Ui
    module Spinner
      # The Spinner preview: the default, a larger one, and a labelled one.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component
        end

        def large
          render_component(class: "size-8")
        end

        def with_context_label
          render_component(label: "Saving your changes")
        end
      end
    end
  end
end
