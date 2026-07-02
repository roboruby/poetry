# frozen_string_literal: true

module Poetry
  module Ui
    module Input
      # The Input preview matrix. Standalone inputs carry an aria-label so
      # each state is accessible on its own; real forms wire the name via
      # Field/FormBuilder instead (see the Field previews).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(type: "email", name: "email", placeholder: "you@example.com",
                           "aria-label" => "Email")
        end

        def with_value
          render_component(name: "city", value: "Lisbon", "aria-label" => "City")
        end

        def disabled
          render_component(name: "plan", value: "Enterprise", disabled: true, "aria-label" => "Plan")
        end

        def invalid
          render_component(type: "email", name: "email", value: "not-an-email", invalid: true,
                           "aria-label" => "Email")
        end
      end
    end
  end
end
