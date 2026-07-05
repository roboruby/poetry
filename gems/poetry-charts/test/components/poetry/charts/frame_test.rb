# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # N10 W1 frame render contracts: the Container scopes + emits the theme
    # style, the tooltip chrome resolves items through the config, the
    # legend derives from the config. The chrome IS the shadcn chart.tsx
    # layer - no engine yet.
    class FrameTest < ViewComponent::TestCase
      CONFIG = {
        desktop: { label: "Desktop", color: "var(--chart-1)" },
        mobile: { label: "Mobile", color: "var(--chart-2)" }
      }.freeze

      # -- Container --------------------------------------------------------

      def test_the_container_scopes_and_emits_the_theme_style
        html = render_inline(Container::Component.new(config: CONFIG, id: "revenue")) do
          "<svg viewBox='0 0 1 1'></svg>".html_safe
        end

        root = html.css('[data-slot="chart"]').first

        assert_equal "chart-revenue", root["data-chart"]
        style = html.css("style").first.text

        assert_includes style, "[data-chart=chart-revenue] {"
        assert_includes style, "--color-desktop: var(--chart-1);"
        assert_includes style, ".dark [data-chart=chart-revenue]"
        assert_predicate html.css("svg"), :any?, "the content block is the chart body"
      end

      def test_the_container_omits_the_style_when_nothing_is_colored
        html = render_inline(Container::Component.new(config: { other: { label: "Other" } }, id: "plain"))

        assert_empty html.css("style")
      end

      def test_container_ids_are_unique_without_an_explicit_id
        first = render_inline(Container::Component.new(config: CONFIG)).css("[data-chart]").first["data-chart"]
        second = render_inline(Container::Component.new(config: CONFIG)).css("[data-chart]").first["data-chart"]

        refute_equal first, second
      end

      # -- TooltipContent ---------------------------------------------------

      def test_tooltip_rows_resolve_names_and_colors_through_the_config
        html = render_inline(TooltipContent::Component.new(
                               config: CONFIG, label: "January",
                               items: [{ key: "desktop", value: 1260 }, { key: "mobile", value: 570 }]
                             ))

        assert_equal "January", html.css('[data-slot="chart-tooltip-label"]').first.text
        names = html.css('[data-slot="chart-tooltip-name"]').map(&:text)

        assert_equal %w[Desktop Mobile], names
        assert_equal "1,260", html.css('[data-slot="chart-tooltip-value"]').first.text
        indicator = html.css('[data-slot="chart-tooltip-indicator"]').first

        assert_includes indicator["style"], "--color-bg: var(--chart-1);"
      end

      def test_the_label_nests_for_a_single_line_indicator_row
        html = render_inline(TooltipContent::Component.new(
                               config: CONFIG, label: "January", indicator: :line,
                               items: [{ key: "desktop", value: 1260 }]
                             ))

        item = html.css('[data-slot="chart-tooltip-item"]').first

        assert_predicate item.css('[data-slot="chart-tooltip-label"]'), :any?,
                         "single-row line tooltips nest the label inside the row"
      end

      def test_hide_flags_suppress_label_and_indicator
        html = render_inline(TooltipContent::Component.new(
                               config: CONFIG, label: "January", hide_label: true, hide_indicator: true,
                               items: [{ key: "desktop", value: 1 }]
                             ))

        assert_empty html.css('[data-slot="chart-tooltip-label"]')
        assert_empty html.css('[data-slot="chart-tooltip-indicator"]')
      end

      # -- LegendContent ----------------------------------------------------

      def test_the_legend_derives_from_the_config
        html = render_inline(LegendContent::Component.new(config: CONFIG))

        items = html.css('[data-slot="chart-legend-item"]')

        assert_equal(%w[Desktop Mobile], items.map { |item| item.text.strip })
        swatch = html.css('[data-slot="chart-legend-swatch"]').first

        assert_includes swatch["style"], "background-color: var(--chart-1);"
      end

      def test_legend_alignment_flips_the_padding_side
        top = render_inline(LegendContent::Component.new(config: CONFIG, align: :top))
              .css('[data-slot="chart-legend-content"]').first

        assert_includes top["class"], "pb-3"
      end

      def test_themed_series_swatch_through_the_scoped_variable
        html = render_inline(LegendContent::Component.new(
                               config: { revenue: { label: "Revenue", theme: { light: "#111", dark: "#eee" } } }
                             ))

        swatch = html.css('[data-slot="chart-legend-swatch"]').first

        assert_includes swatch["style"], "background-color: var(--color-revenue);",
                        "themed entries must follow dark mode via the container's emission"
      end
    end
  end
end
