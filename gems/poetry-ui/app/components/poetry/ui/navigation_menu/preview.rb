# frozen_string_literal: true

module Poetry
  module Ui
    module NavigationMenu
      # The NavigationMenu preview: a bar with a panel item and plain links
      # (the panel opens on hover/click - the dommy tier drives it; the
      # sidecar template composes the panel's link grid).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with_template(template: "poetry/ui/navigation_menu/bar_preview")
        end

        def viewport
          render_with_template(template: "poetry/ui/navigation_menu/viewport_preview")
        end
      end
    end
  end
end
