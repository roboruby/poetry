# frozen_string_literal: true

module Poetry
  module Ui
    module Kbd
      # The Kbd - a real <kbd> element for a keyboard key or shortcut. The
      # content is the key text (⌘, Ctrl, K); compose several for a chord.
      #
      # @example
      #   render Poetry::Ui::Kbd::Component.new { "Esc" }
      class Component < Poetry::Core::Component
        requires_content "the key text"

        AGENT_RULES = [
          "Kbd renders a real <kbd> - the key text is the content block (⌘, Esc, Ctrl).",
          "For a chord (⌘+K) render one Kbd per key inside an inline-flex row."
        ].freeze

        part "kbd", "The <kbd> element itself - the key text renders here"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:kbd, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "kbd" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
