# frozen_string_literal: true

module Poetry
  module Ui
    module Toaster
      # The Toaster preview: the labeled region with a server-rendered
      # stack (the no-JS baseline: flash toasts appear as a static list),
      # plus a top-center corner sample. One toaster per page in real
      # layouts - previews render in isolation.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do
            embed(stack_toast(:success, "Changes saved")) +
              embed(stack_toast(:default, "Event scheduled"))
          end
        end

        def top_center
          render_component(position: :"top-center") do
            embed(stack_toast(:info, "A new version is available"))
          end
        end

        # The stamp path: trigger button + <template> toast + region (the
        # no-round-trip delivery poetry_toast_trigger drives).
        def stamp_trigger
          render_with_template(template: "poetry/ui/toaster/stamp_preview")
        end

        def positions
          # The four placements the examples above don't render, one canvas
          # (axis coverage) - see the template's fixture note.
          render_with_template(template: "poetry/ui/toaster/positions_preview")
        end

        private

        def stack_toast(variant, title)
          Toast::Component.new(variant: variant).tap do |toast|
            toast.with_title { title }
          end
        end
      end
    end
  end
end
