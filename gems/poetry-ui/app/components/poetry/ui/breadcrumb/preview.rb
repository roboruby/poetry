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

        # with_separator swaps the chevron in every gap (upstream
        # breadcrumb#separator - the dot form).
        def dot_separator
          render_component do |crumb|
            crumb.with_separator(icon: :dot)
            crumb.with_item("Home", href: "#")
            crumb.with_item("Components", href: "#")
            crumb.with_item("Breadcrumb")
          end
        end

        # A block item seats a dropdown as a middle crumb (upstream
        # breadcrumb#dropdown) - the axe walk holds the composed menu
        # inside the nav landmark to the same bar as everything else.
        def dropdown_crumb
          render_with_template(template: "poetry/ui/breadcrumb/dropdown_crumb_preview")
        end
      end
    end
  end
end
