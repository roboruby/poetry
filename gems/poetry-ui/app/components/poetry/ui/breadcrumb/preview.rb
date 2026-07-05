# frozen_string_literal: true

module Poetry
  module Ui
    module Breadcrumb
      # The Breadcrumb preview: a plain trail and a collapsed-middle trail.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |crumb|
            crumb.with_item("Home", href: "#")
            crumb.with_item("Components", href: "#")
            crumb.with_item("Breadcrumb")
          end
        end

        def collapsed
          render_component do |crumb|
            crumb.with_item("Home", href: "#")
            crumb.with_ellipsis
            crumb.with_item("Components", href: "#")
            crumb.with_item("Breadcrumb")
          end
        end
      end
    end
  end
end
