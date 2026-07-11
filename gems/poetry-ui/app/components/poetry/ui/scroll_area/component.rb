# frozen_string_literal: true

module Poetry
  module Ui
    module ScrollArea
      # The ScrollArea - a bounded, keyboard-reachable scroll region with
      # themed scrollbars. Deliberately NATIVE (the W3 decision): Base UI
      # rebuilds scrollbars in JS; scrollbar-width/scrollbar-color are
      # Baseline CSS now, so poetry styles the platform's own scrollbars and
      # ships zero JS - scrolling, momentum, and keyboard support come from
      # the browser. The custom-scrollbar machinery returns only if a
      # consumer needs overlay bars.
      #
      # The viewport is focusable (tabindex=0) - a scrollable region a
      # keyboard can't reach fails WCAG (the axe scrollable-region-focusable
      # rule); label: names it (role=region + aria-label).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Size the scroll area with classes (h-72 w-48, max-h-96) - content decides the overflow.",
          "label: is REQUIRED - the viewport is focusable, and a focusable region needs a name " \
          "(role=region + aria-label).",
          "This is a NATIVE scroll surface - never bolt scroll JS onto it; " \
          "use MessageScroller for chat transcripts."
        ].freeze

        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true

        requires_content "what scrolls"

        def before_render
          raise ArgumentError, "ScrollArea requires label: (the region's accessible name)" if label.blank?

          ensure_content!
        end

        def call
          content_tag(:div, root_attributes.to_attributes) do
            content_tag(:div, content, viewport_attributes)
          end
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "scroll-area" }.merge(component_data_attributes)
          )
        end

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
