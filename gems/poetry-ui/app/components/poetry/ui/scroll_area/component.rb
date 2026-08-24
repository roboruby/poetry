# frozen_string_literal: true

module Poetry
  module Ui
    # A bounded scroll region with themed scrollbars.
    module ScrollArea
      # A bounded, keyboard-reachable scroll region with themed
      # scrollbars. Reach for it when content should scroll inside a fixed
      # height or width. Deliberately NATIVE: scrollbar-width and
      # scrollbar-color are Baseline CSS, so the platform's own scrollbars
      # are styled and zero JS ships - scrolling, momentum, and keyboard
      # support come from the browser.
      #
      # The viewport is focusable (tabindex=0) - a scrollable region a
      # keyboard can't reach fails WCAG (the axe scrollable-region-focusable
      # rule); label: names it (role=region + aria-label) and is required.
      #
      # @example A bounded list that scrolls
      #   render Poetry::Ui::ScrollArea::Component.new(label: "Tags", class: "h-72 w-48") do
      #     safe_join(tags.map { |tag| tag.name })
      #   end
      class Component < Poetry::Core::Component
        requires_content "what scrolls"

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Size the scroll area with classes (h-72 w-48, max-h-96) - content decides the overflow.",
          "label: is REQUIRED - the viewport is focusable, and a focusable region needs a name " \
          "(role=region + aria-label).",
          "This is a NATIVE scroll surface - never bolt scroll JS onto it; " \
          "use MessageScroller for chat transcripts."
        ].freeze

        # The region's accessible name (role=region + aria-label) -
        # required, because a focusable region must be named.
        option :label, :string, required: true

        part "scroll-area", "The bounding wrapper - size it with classes; content decides the overflow"
        part "scroll-area-viewport", "The focusable native scroll region (role=region + tabindex=0) " \
                                     "with themed platform scrollbars - zero JS"

        # @api private
        def before_render
          raise ArgumentError, "ScrollArea requires label: (the region's accessible name)" if label.blank?

          ensure_content!
        end

        # @api private
        def call
          content_tag(:div, root_attributes.to_attributes) do
            content_tag(:div, content, viewport_attributes)
          end
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "scroll-area" }.merge(component_data_attributes)
          )
        end

        # @api private
        def viewport_attributes
          {
            "data-slot" => "scroll-area-viewport", "tabindex" => "0",
            "role" => "region", "aria-label" => label,
            "class" => css(:viewport)
          }
        end
      end
    end
  end
end
