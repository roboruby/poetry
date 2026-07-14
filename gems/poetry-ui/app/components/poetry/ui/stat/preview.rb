# frozen_string_literal: true

module Poetry
  module Ui
    module Stat
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Revenue") { "$45,231" }
        end

        def delta_up
          render_component(label: "Active users", delta: "+12.5%", trend: :up) { "2,847" }
        end

        def delta_down
          render_component(label: "Conversion rate", delta: "-0.4pt", trend: :down) { "3.1%" }
        end

        # The inverted metric: DOWN is the good direction, so sentiment
        # overrides the trend-derived color while the arrow stays honest.
        def inverted_down_good
          render_component(label: "Churn", delta: "-0.8%", trend: :down, sentiment: :positive) { "2.1%" }
        end

        def flat
          render_component(label: "Uptime", delta: "0.00%", trend: :flat) { "99.98%" }
        end

        def with_description
          render_component(label: "Open invoices", delta: "+4", trend: :up, sentiment: :negative) do |stat|
            stat.with_description { "12 overdue past 30 days" }
            "38"
          end
        end

        # The media slot: a trend visual under the text stack (a sparkline
        # or chart in a real app; a glyph suffices to pin the anatomy).
        def with_media
          render_component(label: "Deploy frequency", delta: "+18%", trend: :up) do |stat|
            stat.with_media { embed(Poetry::Ui::Icon::Component.new(name: :"trending-up", label: "Trend")) }
            "4.2/day"
          end
        end
      end
    end
  end
end
