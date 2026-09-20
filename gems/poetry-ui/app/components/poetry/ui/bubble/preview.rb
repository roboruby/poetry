# frozen_string_literal: true

module Poetry
  module Ui
    module Bubble
      # The Bubble preview matrix - one corpus for Lookbook, docs, and the
      # agent visual loop.
      class Preview < Poetry::Core::Preview::Base
        # @!group Variants

        def default
          render_component { "Sounds good - see you at 10." }
        end

        def secondary
          render_component(variant: :secondary) { "Here's the summary you asked for." }
        end

        def muted
          render_component(variant: :muted) { "Typing indicator context." }
        end

        def tinted
          render_component(variant: :tinted) { "A tinted assistant reply." }
        end

        def outline
          render_component(variant: :outline) { "An outlined reply." }
        end

        def ghost
          render_component(variant: :ghost) { "Tool output flows full-width without a surface." }
        end

        def destructive
          render_component(variant: :destructive) { "That upload failed." }
        end

        # @!endgroup

        def align_end
          render_component(align: :end) { "Sent by me." }
        end

        def quick_reply_button
          render_component(variant: :outline, tag: :button) { "Yes, book it" }
        end

        def quick_reply_link
          render_component(variant: :outline, tag: :a, href: "/details") { "View details" }
        end

        def with_reactions
          render_component do |bubble|
            bubble.with_reactions(label: "Reactions: thumbs up") { "👍" }
            "Great idea!"
          end
        end
      end
    end
  end
end
