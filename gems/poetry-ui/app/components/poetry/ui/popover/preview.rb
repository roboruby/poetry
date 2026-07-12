# frozen_string_literal: true

module Poetry
  module Ui
    module Popover
      # The Popover preview matrix: the shadcn popover-demo composition
      # (form-in-popover, w-80 override) plus both modality modes, the
      # anchor part, the label: naming fallback, a placement sample, and
      # the server-rendered open state.
      class Preview < Poetry::Core::Preview::Base
        # The popover-demo port: outline Button trigger, titled/described
        # panel, the dimensions form in upstream's grid rows (the sidecar
        # preview.html.erb - herb-scanned, so the layout classes reach the
        # safelist), the demo's w-80 class override.
        def default
          render_with(component: Component.new(content_class: "w-80"))
        end

        # modal: true - focus-scope trapped + the dismissable scrim.
        def modal
          render_with(component: Component.new(content_class: "w-80", modal: true))
        end

        # The anchor part takes the popper anchor target: the panel
        # positions against IT, not the trigger (Radix PopoverAnchor).
        def with_anchor
          render_component do |popover|
            popover.with_trigger(variant: :outline) { "Open popover" }
            popover.with_anchor { "The panel anchors to this text, not the button." }
            popover.with_title { "Anchored" }
            "Positioned against the anchor part."
          end
        end

        # No title part: label: names the role=dialog via aria-label.
        def named_by_label
          render_component(label: "Quick settings") do |popover|
            popover.with_trigger(variant: :outline) { "Settings" }
            "A panel named by label: instead of a title part."
          end
        end

        # Server-rendered open state (controllable-state: the attributes
        # are the store; the controller reconciles on connect).
        def open
          render_component(open: true) do |popover|
            popover.with_trigger(variant: :outline) { "Open popover" }
            popover.with_title { "Server-opened" }
            popover.with_description { "Rendered open - fully usable before (or without) JS." }
            "Static content."
          end
        end

        # Placement sample (side/align flow through to popper; data-side
        # re-resolves live on collision).
        def side_top
          render_component(side: :top, align: :start) do |popover|
            popover.with_trigger(variant: :outline) { "Open above" }
            popover.with_title { "Placement" }
            "side: :top, align: :start"
          end
        end
      end
    end
  end
end
