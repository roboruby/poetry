# frozen_string_literal: true

module Poetry
  module Charts
    # poetry's port of shadcn's ChartStyle: turns a chart's Config into the
    # scoped per-series custom properties, one block per theme -
    #
    #   [data-chart=chart-revenue] { --color-desktop: var(--chart-1); }
    #   .dark [data-chart=chart-revenue] { --color-desktop: oklch(...); }
    #
    # so series markup (SVG fills, tooltip indicators, legend swatches) can
    # reference var(--color-<key>) and follow theme flips with ZERO
    # re-render. Emission is safe by construction: Config validated every
    # key and color at wrap time.
    class ThemeStyle
      # Theme name -> selector prefix (the.dark class convention).
      THEMES = { light: "", dark: ".dark " }.freeze

      def initialize(id:, config:)
        @id = id
        @config = Config.wrap(config)
      end

      # The stylesheet text, or nil when no entry carries a color (shadcn
      # renders no <style> at all in that case - so do we).
      def css
        entries = @config.color_entries
        return nil if entries.empty?

        THEMES.filter_map { |theme, prefix| theme_block(theme, prefix, entries) }.join("\n")
      end

      private

      def theme_block(theme, prefix, entries)
        declarations = entries.filter_map do |entry|
          color = entry.color_for(theme)
          "  --color-#{entry.key}: #{color};" if color
        end
        return nil if declarations.empty?

        "#{prefix}[data-chart=#{@id}] {\n#{declarations.join("\n")}\n}"
      end
    end
  end
end
