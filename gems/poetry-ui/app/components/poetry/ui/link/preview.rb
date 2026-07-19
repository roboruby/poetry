# frozen_string_literal: true

module Poetry
  module Ui
    module Link
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(href: "#") { "Documentation" }
        end

        def current_nav_item
          render_component(href: "#", current: true) { "Dashboard" }
        end

        def external
          render_component(href: "https://example.com", external: true) { "API reference" }
        end

        def always_underlined
          render_component(href: "#", underline: :always) { "Terms of service" }
        end

        def never_underlined
          render_component(href: "#", underline: :none) { "Settings" }
        end
      end
    end
  end
end
