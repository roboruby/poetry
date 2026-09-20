# frozen_string_literal: true

module Poetry
  module Ui
    module NativeSelect
      # The NativeSelect preview: the labelled pair (its whole a11y
      # contract), plus small/disabled states.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with_template(template: "poetry/ui/native_select/labelled_preview")
        end

        def small_disabled
          render_component(size: :sm, disabled: true, name: "plan", id: "native-select-plan",
                           label: "Plan", options: %w[Starter Team], selected: "Team")
        end
      end
    end
  end
end
