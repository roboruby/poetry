# frozen_string_literal: true

module Poetry
  module Ui
    module Card
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |card|
            card.with_title { "Revenue" }
            card.with_description { "Last 30 days" }
            "$12,345"
          end
        end

        def with_action_and_footer
          render_component do |card|
            card.with_title { "Team" }
            card.with_description { "Active members" }
            card.with_action { embed(Poetry::Ui::Button::Component.new(size: :sm, variant: :outline).with_content("Invite")) }
            card.with_footer { "Updated hourly" }
            "24 members"
          end
        end
      end
    end
  end
end
