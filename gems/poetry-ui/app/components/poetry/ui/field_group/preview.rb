# frozen_string_literal: true

module Poetry
  module Ui
    module FieldGroup
      # The stacking container over real wired Fields - rendering rides
      # the sidecar preview.html.erb (the Field preview precedent).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with(component: Component.new)
        end

        # The tighter checkbox-run rhythm (upstream's checkbox-group form).
        def choices
          render_with(component: Component.new(variant: :choices), choices: true)
        end
      end
    end
  end
end
