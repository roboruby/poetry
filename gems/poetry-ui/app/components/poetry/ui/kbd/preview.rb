# frozen_string_literal: true

module Poetry
  module Ui
    module Kbd
      # The Kbd preview: single keys.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component { "Esc" }
        end

        def command
          render_component { "⌘" }
        end

        # A chord run in the themed group wrapper.
        def group
          render_with_template(template: "poetry/ui/kbd/group_preview")
        end
      end
    end
  end
end
