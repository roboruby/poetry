# frozen_string_literal: true

module Demo
  # The dummy host's own component: an app component written on the
  # Poetry DSL, declaring its helper. The host-components tests render it
  # through the helper, lint it through poetry check, and read it from
  # llms-full.txt.
  module Badge
    class Component < Poetry::Core::Component
      helper :demo_badge

      requires_content "the visible label"

      AGENT_RULES = ["Demo badges are read-only labels; never attach click handlers."].freeze

      style :tone, default: :neutral, required: true, variants: %i[neutral loud],
                   doc: "How loud the label reads."

      part "badge", "The label itself (one <span>)"

      def before_render
        ensure_content!
      end

      def call
        content_tag(:span, content, class: css)
      end
    end

    class Style < Poetry::Core::Style
      # Real utilities: the gem's compiled-CSS gate holds every loaded
      # dictionary, this one included, to a real Tailwind build.
      base "inline-flex items-center rounded-md px-2 text-xs"
      variant :tone, neutral: "bg-muted text-muted-foreground", loud: "bg-primary text-primary-foreground"
    end
  end
end
