# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Every registered chart component answers to poetry_<name>: the name
    # the registry, poetry check, llms.txt, and the skills derive. The
    # fresh-app proof for the ui gem caught helpers missing; this is the
    # same gate for the chart families.
    class ComponentsHelperTest < ActionDispatch::IntegrationTest
      CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" },
                 mobile: { label: "Mobile", color: "var(--chart-2)" } }.freeze
      DATA = [{ month: "Jan", desktop: 10, mobile: 4 }, { month: "Feb", desktop: 12, mobile: 6 }].freeze
      POINTS = [{ height: 160, weight: 55 }, { height: 175, weight: 70 }].freeze
      SLICES = [{ browser: "chrome", visitors: 3, fill: "var(--color-chrome)" },
                { browser: "safari", visitors: 2, fill: "var(--color-safari)" }].freeze
      SLICE_CONFIG = { visitors: { label: "Visitors" }, chrome: { label: "Chrome", color: "var(--chart-1)" },
                       safari: { label: "Safari", color: "var(--chart-2)" } }.freeze

      def render_erb(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end

      def test_every_registered_component_has_its_helper
        Poetry::Core::Registry.new(source_root: Poetry::Charts.root).components.each do |component|
          helper = "poetry_#{component.name.deconstantize.demodulize.underscore}"

          assert_includes ComponentsHelper.instance_methods, helper.to_sym,
                          "missing #{helper} - every registered component ships its helper"
        end
      end

      def test_legacy_chart_prefixed_names_stay_as_aliases
        %i[poetry_chart_container poetry_chart_tooltip_content poetry_chart_legend_content].each do |name|
          assert_includes ComponentsHelper.instance_methods, name
        end
      end

      def test_every_cartesian_family_renders_through_its_helper
        { poetry_area_chart: :with_area, poetry_line_chart: :with_line, poetry_bar_chart: :with_bar,
          poetry_composed_chart: :with_bar }.each do |helper, mark|
          html = render_erb(<<~ERB)
            <%= #{helper}(data: #{DATA.inspect}, config: #{CONFIG.inspect}, id: "#{helper}") do |chart| %>
              <% chart.with_x_axis data_key: :month %>
              <% chart.#{mark} data_key: :desktop %>
            <% end %>
          ERB

          assert_includes html, "<svg", "#{helper} renders an SVG"
        end

        html = render_erb(<<~ERB)
          <%= poetry_scatter_chart(data: #{POINTS.inspect}, config: { sample: { label: "Sample", color: "var(--chart-1)" } }, id: "scatter") do |chart| %>
            <% chart.with_x_axis data_key: :height %>
            <% chart.with_y_axis data_key: :weight %>
            <% chart.with_scatter key: :sample %>
          <% end %>
        ERB

        assert_includes html, "<svg", "poetry_scatter_chart renders an SVG"
      end

      def test_every_polar_family_renders_through_its_helper
        html = render_erb(<<~ERB)
          <%= poetry_pie_chart(data: #{SLICES.inspect}, config: #{SLICE_CONFIG.inspect}, id: "pie") do |chart| %>
            <% chart.with_pie data_key: :visitors, name_key: :browser, inner_radius: 30 %>
          <% end %>
        ERB
        assert_includes html, "<svg"

        html = render_erb(<<~ERB)
          <%= poetry_radar_chart(data: #{DATA.inspect}, config: #{CONFIG.inspect}, id: "radar") do |chart| %>
            <% chart.with_radar data_key: :desktop %>
          <% end %>
        ERB
        assert_includes html, "<svg"

        html = render_erb(<<~ERB)
          <%= poetry_radial_bar_chart(data: #{SLICES.inspect}, config: #{SLICE_CONFIG.inspect}, id: "radial") do |chart| %>
            <% chart.with_radial_bar data_key: :visitors %>
          <% end %>
        ERB
        assert_includes html, "<svg"
      end

      def test_support_components_render_under_both_names
        old = render_erb(%(<%= poetry_chart_legend_content(config: #{CONFIG.inspect}) %>))
        new = render_erb(%(<%= poetry_legend_content(config: #{CONFIG.inspect}) %>))

        assert_equal old, new
        assert_includes new, 'data-component="legend_content"'
      end
    end
  end
end
