# frozen_string_literal: true

module Poetry
  module Ui
    module Timeline
      # The Timeline - a sequence of dated events as a real ordered
      # list: activity feeds, order status,
      # deploy history. Each item wears a decorative indicator (a dot, or
      # icon:'s glyph) on a connector rail; completed: marks progress and
      # recolors the item's indicator and rail segment. No upstream
      # shadcn/Base UI analogue; the anatomy follows ReUI's Timeline on
      # <ol>/<li> semantics (the MetadataList precedent: the platform
      # element the pattern owes its readers). Styling is utility-only
      # (the Separator/Spinner rule): data-slot names are the restyle seam.
      #
      # @example
      #   render Poetry::Ui::Timeline::Component.new do |timeline|
      #     timeline.with_item(title: "Order placed", time: "Mar 15", completed: true)
      #     timeline.with_item(title: "In transit") { "Estimated delivery Thursday." }
      #   end
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "A sequence of dated events (activity feed, order status, deploy history) is a " \
          "Timeline - never a hand-rolled stack of dots and left borders (this is the <ol> " \
          "the sequence owes its readers).",
          "Each with_item takes title:, optional time: (renders a <time>), optional icon: " \
          "(swaps the dot for a glyph), completed: for progress - the description is the block.",
          "completed: colors the item's indicator and its rail segment - mark every step up to " \
          "the current one, not just the latest.",
          "orientation: :horizontal lays the steps left-to-right (an order tracker); the " \
          "vertical default reads as a feed. For steps the USER advances through, use " \
          "Stepper - a Timeline records, it never navigates."
        ].freeze

        # The same fact the before_render raise enforces, stated
        # statically: poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { item: "at least one item (title:, with the description as its block)" }.freeze

        renders_many :items, lambda { |title:, time: nil, icon: nil, completed: false,
                                       **options, &block|
          attrs = { "data-slot" => "timeline-item", class: css(:item) }
          attrs["data-completed"] = "" if completed
          content_tag(:li, attrs.merge(options)) do
            body = [item_indicator(icon), item_separator, item_header(title, time)]
            if block
              body << content_tag(:div, { "data-slot" => "timeline-content",
                                          class: css(:content) }, &block)
            end
            safe_join(body)
          end
        }

        style :orientation, default: :vertical, variants: %i[vertical horizontal]

        part "timeline", "The <ol> root - the event sequence",
             states: {
               "data-orientation" => { condition: "always - the layout axis",
                                       values: %w[vertical horizontal] }
             }
        part "timeline-item", "One event (<li>): indicator + rail segment + header + description",
             states: {
               "data-completed" => "the step is done - recolors its indicator and rail segment"
             }
        part "timeline-indicator", "The decorative marker on the rail - a dot, or icon:'s glyph " \
                                   "(aria-hidden; the sequence lives in the list semantics)"
        part "timeline-separator", "The decorative rail segment toward the next item - hidden " \
                                   "on the last"
        part "timeline-header", "The title/time row"
        part "timeline-title", "The event's name"
        part "timeline-time", "The event's <time> - muted, small"
        part "timeline-content", "Muted description under the header (the item's block)"

        def before_render
          raise ArgumentError, "Timeline requires at least one with_item" unless items?
        end

        def call
          content_tag(:ol, safe_join(items.map(&:to_s)), **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "timeline", "data-orientation" => orientation }
              .merge(component_data_attributes)
          )
        end

        private

        # Decorative twins (the Tree toggle-spacer rule): indicator and
        # rail carry no semantics - the sequence is the <ol>, progress is
        # data-completed.
        def item_indicator(icon)
          content_tag(:div, "data-slot" => "timeline-indicator", "aria-hidden" => "true",
                            "class" => css(:indicator)) do
            if icon
              render(Icon::Component.new(name: icon, class: css(:indicator_icon)))
            else
              content_tag(:span, nil, class: css(:indicator_dot))
            end
          end
        end

        def item_separator
          content_tag(:div, nil, "data-slot" => "timeline-separator", "aria-hidden" => "true",
                                 "class" => css(:separator))
        end

        def item_header(title, time)
          content_tag(:div, "data-slot" => "timeline-header", class: css(:header)) do
            parts = [content_tag(:div, title, "data-slot" => "timeline-title", class: css(:title))]
            parts << content_tag(:time, time, "data-slot" => "timeline-time", class: css(:time)) if time
            safe_join(parts)
          end
        end
      end
    end
  end
end
