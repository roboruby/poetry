# frozen_string_literal: true

module Poetry
  module Ui
    module Tabs
      # The Tabs preview: the default boxed list, the line variant, and a
      # vertical set with a disabled tab.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Account settings") do |tabs|
            tabs.with_tab("Account", value: "account") { "Make changes to your account here." }
            tabs.with_tab("Password", value: "password") { "Change your password here." }
          end
        end

        def line_variant
          render_component(variant: :line, label: "Docs sections", default: "usage") do |tabs|
            tabs.with_tab("Overview", value: "overview") { "The component at a glance." }
            tabs.with_tab("Usage", value: "usage") { "How to compose it." }
            tabs.with_tab("API", value: "api") { "Options and slots." }
          end
        end

        # The list-only arrangement (panel: false): no tabpanels at all,
        # triggers without aria-controls - upstream's line/disabled demos.
        def list_only
          render_component(label: "List-only demo") do |tabs|
            tabs.with_tab("Home", value: "home", panel: false)
            tabs.with_tab("Disabled", value: "settings", disabled: true, panel: false)
          end
        end

        def vertical_with_disabled
          render_component(orientation: :vertical, label: "Project areas") do |tabs|
            tabs.with_tab("General", value: "general") { "Project defaults." }
            tabs.with_tab("Members", value: "members") { "Who has access." }
            tabs.with_tab("Billing", value: "billing", disabled: true) { "Plan and invoices." }
          end
        end
      end
    end
  end
end
