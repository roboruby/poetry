# frozen_string_literal: true

module Poetry
  module Ui
    module Collapsible
      # The Collapsible preview matrix.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |collapsible|
            collapsible.with_trigger(variant: :ghost, size: :sm) { "Show details" }
            tag.div("Hidden until disclosed.", class: "pt-2 text-sm text-muted-foreground")
          end
        end

        def initially_open
          render_component(open: true) do |collapsible|
            collapsible.with_trigger(variant: :ghost, size: :sm) { "Hide details" }
            tag.div("Server-rendered open.", class: "pt-2 text-sm text-muted-foreground")
          end
        end
      end
    end
  end
end
