# frozen_string_literal: true

module Poetry
  module Ui
    module Skeleton
      # The Skeleton preview: placeholders in the common shapes.
      class Preview < Poetry::Core::Preview::Base
        def line
          render_component(class: "h-4 w-48")
        end

        def avatar
          render_component(class: "size-12 rounded-full")
        end

        def block
          render_component(class: "h-24 w-full rounded-xl")
        end
      end
    end
  end
end
