# frozen_string_literal: true

module Poetry
  module Ui
    module Progress
      # The Progress preview: mid-flight, complete, and a custom max.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(value: 60, label: "Uploading photos")
        end

        def complete
          render_component(value: 100, label: "Backup")
        end

        def custom_max_without_value
          render_component(value: 3, max: 8, label: "Steps completed", show_value: false)
        end
      end
    end
  end
end
