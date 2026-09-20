# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The ChartStyle port: scoped --color-<key> custom properties, one block
    # per theme, exactly the shadcn emission shape.
    class ThemeStyleTest < ActiveSupport::TestCase
      def test_emits_scoped_custom_properties
        css = ThemeStyle.new(
          id: "chart-r1",
          config: { desktop: { color: "var(--chart-1)" }, mobile: { color: "var(--chart-2)" } }
        ).css

        assert_includes css, "[data-chart=chart-r1] {"
        assert_includes css, "  --color-desktop: var(--chart-1);"
        assert_includes css, "  --color-mobile: var(--chart-2);"
      end

      def test_theme_maps_emit_light_and_dark_blocks
        css = ThemeStyle.new(
          id: "chart-r2",
          config: { revenue: { theme: { light: "#0ea5e9", dark: "#38bdf8" } } }
        ).css

        assert_includes css, "[data-chart=chart-r2] {\n  --color-revenue: #0ea5e9;\n}"
        assert_includes css, ".dark [data-chart=chart-r2] {\n  --color-revenue: #38bdf8;\n}"
      end

      def test_flat_colors_repeat_in_both_theme_blocks
        css = ThemeStyle.new(id: "chart-r3", config: { desktop: { color: "var(--chart-1)" } }).css

        assert_includes css, ".dark [data-chart=chart-r3]"
      end

      def test_nil_when_nothing_is_colored
        assert_nil ThemeStyle.new(id: "chart-r4", config: { other: { label: "Other" } }).css
        assert_nil ThemeStyle.new(id: "chart-r5", config: {}).css
      end
    end
  end
end
