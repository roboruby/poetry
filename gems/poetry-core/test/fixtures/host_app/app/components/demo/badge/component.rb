# frozen_string_literal: true

# A host application's own component, on the DSL, declaring its helper.
module Demo
  module Badge
    class Component < Poetry::Core::Component
      helper :demo_badge

      AGENT_RULES = ["Demo badges are read-only labels; never attach click handlers."].freeze

      style :tone, default: :neutral, variants: %i[neutral loud]

      def call
        content_tag(:span, content, class: css)
      end
    end

    class Style < Poetry::Core::Style
      base "demo-badge"
      variant :tone, neutral: "demo-badge-neutral", loud: "demo-badge-loud"
    end

    # An inner class: full machinery, no registry entry, no helper.
    class Item < Poetry::Core::Component
      internal_component!

      def call
        content_tag(:i, content)
      end
    end
  end
end
