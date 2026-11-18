# frozen_string_literal: true

module Poetry
  module Motion
    module Background
      # Background previews: each pattern and effect behind a heading.
      class Preview < Poetry::Core::Preview::Base
        def default
          hero(pattern: :grid)
        end

        def dots_and_meteors
          hero(pattern: :dots, effect: :meteors)
        end

        def aurora
          hero(pattern: :none, effect: :aurora, fade: :bottom)
        end

        def retro_grid
          hero(pattern: :none, effect: :retro_grid, fade: :none)
        end

        def ripple
          hero(pattern: :none, effect: :ripple, count: 5)
        end

        private

        def hero(**)
          render_component(class: "flex h-72 items-center justify-center rounded-xl border", **) do
            tag.h2("Finished on the server", class: "text-2xl font-semibold")
          end
        end
      end
    end
  end
end
