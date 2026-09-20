# frozen_string_literal: true

module Poetry
  module Ui
    module AspectRatio
      # The AspectRatio preview: the common shapes, each holding a muted
      # placeholder that fills the locked box.
      class Preview < Poetry::Core::Preview::Base
        def video
          render_component(ratio: "16/9", class: "w-64 overflow-hidden rounded-lg bg-muted") do
            tag.div("16 / 9", class: "flex size-full items-center justify-center text-sm text-muted-foreground")
          end
        end

        def square
          render_component(ratio: "1", class: "w-40 overflow-hidden rounded-lg bg-muted") do
            tag.div("1 / 1", class: "flex size-full items-center justify-center text-sm text-muted-foreground")
          end
        end

        def portrait
          render_component(ratio: "9/16", class: "w-24 overflow-hidden rounded-lg bg-muted") do
            tag.div("9 / 16", class: "flex size-full items-center justify-center text-sm text-muted-foreground")
          end
        end
      end
    end
  end
end
