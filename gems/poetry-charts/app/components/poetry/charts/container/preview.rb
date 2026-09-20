# frozen_string_literal: true

module Poetry
  module Charts
    module Container
      # The frame previewed standalone: config-driven series colors flowing
      # into inline SVG through var(--color-<key>) - the whole container
      # contract, before any engine exists.
      class Preview < Poetry::Core::Preview::Base
        CONFIG = {
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        def default
          render_component(config: CONFIG, id: "preview") do
            <<~SVG.html_safe
              <svg viewBox="0 0 300 150" style="height:100%;width:100%" role="img" aria-label="Placeholder chart">
                <rect x="20" y="60" width="40" height="80" rx="4" fill="var(--color-desktop)"></rect>
                <rect x="70" y="30" width="40" height="110" rx="4" fill="var(--color-mobile)"></rect>
                <rect x="130" y="80" width="40" height="60" rx="4" fill="var(--color-desktop)"></rect>
                <rect x="180" y="45" width="40" height="95" rx="4" fill="var(--color-mobile)"></rect>
              </svg>
            SVG
          end
        end

        def themed
          render_component(
            config: {
              revenue: { label: "Revenue", theme: { light: "oklch(0.6 0.15 250)", dark: "oklch(0.75 0.12 250)" } }
            },
            id: "preview-themed"
          ) do
            <<~SVG.html_safe
              <svg viewBox="0 0 300 150" style="height:100%;width:100%" role="img" aria-label="Themed placeholder chart">
                <circle cx="150" cy="75" r="50" fill="var(--color-revenue)"></circle>
              </svg>
            SVG
          end
        end
      end
    end
  end
end
