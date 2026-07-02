# frozen_string_literal: true

module Poetry
  module Ui
    module MessageScroller
      # The MessageScroller preview - a bounded transcript frame (the
      # geometry behaviors need the browser loop; previews cover markup).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(id: "demo", class: "h-80 rounded-lg border") do
            safe_join(Array.new(12) { |i| item("m#{i}") { row(i) } })
          end
        end

        def without_jump_button
          render_component(id: "plain", jump_button: false, class: "h-60 rounded-lg border") do
            item("only") { row(0) }
          end
        end

        private

        def item(id, &)
          tag.div(class: Style.css(:item), data: { slot: "message-scroller-item", "message-id": id }, &)
        end

        def row(index)
          tag.div("Message #{index + 1}", class: "rounded-xl bg-muted px-3 py-2 w-fit")
        end
      end
    end
  end
end
