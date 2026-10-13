# frozen_string_literal: true

module Poetry
  module Motion
    module AnimatedList
      # Animated list preview: a feed as the server renders it.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(class: "flex max-w-sm flex-col gap-2") do
            safe_join(%w[Deployed Reviewed Merged].map do |event|
              tag.li("Pull request #{event.downcase}", class: "rounded-md border px-3 py-2 text-sm")
            end)
          end
        end
      end
    end
  end
end
