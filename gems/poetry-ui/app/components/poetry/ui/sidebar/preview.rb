# frozen_string_literal: true

module Poetry
  module Ui
    module Sidebar
      # The Sidebar preview: the app shell in the icon-collapsible and
      # offcanvas modes (the sidecar template composes the full nav + inset,
      # since it is a helper-heavy structure).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with_template(template: "poetry/ui/sidebar/shell_preview", locals: { collapsible: :icon })
        end

        def offcanvas_collapsed
          render_with_template(template: "poetry/ui/sidebar/shell_preview",
                               locals: { collapsible: :offcanvas, open: false })
        end
      end
    end
  end
end
