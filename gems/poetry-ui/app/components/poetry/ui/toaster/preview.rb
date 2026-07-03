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
