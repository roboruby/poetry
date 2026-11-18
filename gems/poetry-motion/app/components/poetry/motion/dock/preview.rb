# frozen_string_literal: true

module Poetry
  module Motion
    module Dock
      # Dock preview: five launcher items.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Apps") do
            safe_join(%w[Mail Notes Music Photos Maps].map do |app|
              tag.a(app[0], href: "#", "aria-label" => app,
                            class: "flex size-10 items-center justify-center rounded-xl bg-muted font-semibold")
            end)
          end
        end
      end
    end
  end
end
