# frozen_string_literal: true

module Poetry
  module Motion
    module SwipeCards
      # A stack of cards to swipe through, one decision each: drag the top
      # card left or right past the threshold, press the arrow keys on the
      # focused stack, or wire your own buttons to swipeLeft and swipeRight.
      # with_actions renders inside the stack, so its buttons reach the
      # controller. Each swipe dispatches poetry--motion--swipe-cards:swipe with
      # { direction, card, index }; record it there (a form post, a Turbo
      # Stream). When the last card goes, the with_empty content shows.
      #
      # @example
      #   <%= poetry_swipe_cards(label: "Candidates") do |stack| %>
      #     <% candidates.each do |candidate| %>
      #       <% stack.with_card(data: { id: candidate.id }) { render candidate } %>
      #     <% end %>
      #     <% stack.with_empty { "That's everyone." } %>
      #     <% stack.with_actions do %>
      #       <%= poetry_button(variant: :outline,
      #                         data: { action: "poetry--motion--swipe-cards#swipeLeft" }) { "Skip" } %>
      #       <%= poetry_button(data: { action: "poetry--motion--swipe-cards#swipeRight" }) { "Keep" } %>
      #     <% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "Swiping is one way to decide, never the only one: give the stack a label:, and put buttons " \
          "beside it wired to poetry--motion--swipe-cards#swipeLeft and #swipeRight.",
          "The swipe event is the decision; persist it from the event. The cards themselves are not a form."
        ].freeze

        use_behavior :drag
        use_behavior :animate

        renders_many :cards,
                     doc: "One card; the first is on top. Options ride onto the card's element.",
                     renders: lambda { |**options, &block|
                       attrs = { "data-slot" => "swipe-cards-card", class: css(:card, class: options.delete(:class)),
                                 **stimulus_attributes_for(:card) }
                       content_tag(:div, capture(&block), **Poetry::Core::HTML::Attributes.merged(attrs, options))
                     }
        renders_one :empty, doc: "What shows once every card is swiped away."
        renders_one :actions,
                    doc: "Buttons under the stack; wire them to poetry--motion--swipe-cards#swipeLeft and #swipeRight."

        use_stimulus do
          on :root do
            controller :swipe_cards do
              register
              value :threshold
            end
          end
          on :card do
            controller(:swipe_cards) { target :card }
          end
        end

        option :label, :string, required: true, doc: "What the stack holds, for a screen reader."
        option :threshold, :integer, default: 100, doc: "Pixels of drag that commit a swipe."

        part "swipe-cards", "The focusable stack; the arrow keys swipe its top card",
             states: { "data-empty" => "every card has been swiped" }
        part "swipe-cards-card", "One card",
             states: { "data-top" => "the card on top, the one that takes the pointer",
                       "data-dismissed" => { condition: "it was swiped, which way", values: %w[left right] },
                       "data-dragging" => "the card is being dragged" },
             vars: { "--swipe-rotate" => "the tilt while it drags" }
        part "swipe-cards-deck", "The cell the cards share"
        part "swipe-cards-empty", "What shows once every card is gone"
        part "swipe-cards-actions", "The buttons under the stack"

        def before_render
          ensure_within!(:threshold, 20..600)
        end

        def call
          tag.div(**root_attributes) do
            parts = cards.map(&:to_s)
            parts << content_tag(:div, empty, "data-slot" => "swipe-cards-empty", class: css(:empty)) if empty?
            deck = content_tag(:div, safe_join(parts.map(&:html_safe)), "data-slot" => "swipe-cards-deck",
                                                                        class: css(:deck))
            row = (content_tag(:div, actions, "data-slot" => "swipe-cards-actions", class: css(:actions)) if actions?)
            safe_join([deck, row].compact)
          end
        end

        def root_attributes
          super("role" => "group", "aria-label" => label, "aria-roledescription" => "swipe stack", "tabindex" => "0")
        end
      end
    end
  end
end
