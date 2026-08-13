# frozen_string_literal: true

module Poetry
  module Ui
    module Alert
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |alert|
            alert.with_title { "Heads up" }
            "You can adjust preferences at any time."
          end
        end

        def destructive
          render_component(variant: :destructive) do |alert|
            alert.with_icon(name: :"triangle-alert")
            alert.with_title { "Payment failed" }
            "Your card was declined - update your billing details."
          end
        end

        # The corner action well (theme pins it top-right).
        def with_action
          render_component(variant: :default) do |alert|
            alert.with_title { "Update available" }
            alert.with_action { tag.button("Dismiss", type: "button", class: "text-sm underline-offset-4 hover:underline") }
            "A new version is ready to install."
          end
        end
      end
    end
  end
end
