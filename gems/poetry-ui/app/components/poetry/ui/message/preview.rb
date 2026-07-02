# frozen_string_literal: true

module Poetry
  module Ui
    module Message
      # The Message preview matrix.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |message|
            message.with_avatar { "AI" }
            message.with_header { "Assistant" }
            tag.div("Here's the plan for today.", class: "rounded-xl bg-muted px-3 py-2 w-fit")
          end
        end

        def align_end
          render_component(align: :end) do |message|
            message.with_footer { "Read 10:42" }
            tag.div("Sounds good!", class: "rounded-xl bg-primary text-primary-foreground px-3 py-2 w-fit")
          end
        end

        def with_footer_lifts_avatar
          render_component do |message|
            message.with_avatar { "AI" }
            message.with_footer { "10:41" }
            tag.div("Footer present - the avatar lifts.", class: "rounded-xl bg-muted px-3 py-2 w-fit")
          end
        end
      end
    end
  end
end
