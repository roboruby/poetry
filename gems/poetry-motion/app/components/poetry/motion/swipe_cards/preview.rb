# frozen_string_literal: true

module Poetry
  module Motion
    module SwipeCards
      # Swipe cards preview: three cards and an empty state.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Candidates", class: "w-72") do |stack|
            %w[Ada Grace Edsger].each do |name|
              stack.with_card { tag.div(name, class: "rounded-xl border bg-card p-10 text-center text-lg shadow-sm") }
            end
            stack.with_empty { "That's everyone." }
            stack.with_actions do
              safe_join([%w[Skip swipeLeft], %w[Keep swipeRight]].map do |label, action|
                tag.button(label, type: "button", class: "rounded-md border px-3 py-1 text-sm",
                                  data: { action: "poetry--motion--swipe-cards##{action}" })
              end)
            end
            nil
          end
        end
      end
    end
  end
end
