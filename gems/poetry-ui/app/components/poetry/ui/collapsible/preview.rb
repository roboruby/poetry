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

        # The height animation over the controller-measured panel size.
        def animated
          render_component(open: true, content_class: ANIMATED_CONTENT) do |collapsible|
            collapsible.with_trigger(variant: :ghost, size: :sm) { "Hide details" }
            tag.div("The panel animates its height both ways.", class: "pt-2 text-sm text-muted-foreground")
          end
        end

        # The height-animation classes (Base UI's --collapsible-panel-height idiom).
        ANIMATED_CONTENT = "h-(--collapsible-panel-height) overflow-hidden transition-[height] duration-200 " \
                           "ease-out data-starting-style:h-0 data-ending-style:h-0"
      end
    end
  end
end
