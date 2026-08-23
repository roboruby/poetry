# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The adapter door's render contracts - the one-word engine
    # swap, the server-validated frozen spec, the mount wiring, and the
    # spec-v1 schema freeze itself.
    class AdapterChartTest < ViewComponent::TestCase
      DATA = [{ month: "Jan", desktop: 186 }, { month: "Feb", desktop: 305 }].freeze
      CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze

      def render_adapter(**)
        render_inline(AdapterChart::Component.new(
                        type: :bar, engine: "chartjs", data: DATA, config: CONFIG, id: "a",
                        series: [{ data_key: :desktop }], axes: { x: { data_key: :month } }, **
                      ))
      end

      def test_the_mount_carries_the_engine_and_the_frozen_spec
        html = render_adapter

        controller = html.css("[data-controller='poetry--charts--adapter']").first

        assert controller
        assert_equal "chartjs", controller["data-poetry--charts--adapter-engine-value"]
        assert_predicate html.css('[data-slot="chart-adapter-mount"][data-poetry--charts--adapter-target="mount"]'),
                         :any?
        spec = JSON.parse(html.css('[data-slot="chart-spec"]').first.text)

        assert_equal 1, spec["version"]
        assert_equal "bar", spec["type"]
        assert_equal "desktop", spec["series"].first["dataKey"]
        assert_equal "Desktop", spec["config"]["desktop"]["label"]
      end

      def test_the_container_contract_still_wraps_the_mount
        html = render_adapter

        assert_predicate html.css('[data-chart="chart-a"]'), :any?
        assert_includes html.css("style").first.text, "--color-desktop: var(--chart-1);"
      end

      def test_bad_specs_raise_at_render_not_in_the_browser
        assert_raises(ArgumentError) do
          render_adapter(series: [{ data_key: :desktop, library: { evil: true } }])
        end
      end

      def test_the_dispatcher_swaps_on_one_word
        html = vc_test_controller.view_context.poetry_chart(
          :bar, engine: "chartjs", data: DATA, config: CONFIG, id: "via",
                series: [{ data_key: :desktop }], axes: { x: { data_key: :month } }
        )

        assert_includes html, "chart-adapter-mount"
      end

      def test_the_adapter_path_refuses_slots
        error = assert_raises(ArgumentError) do
          vc_test_controller.view_context.poetry_chart(:bar, engine: "chartjs", data: DATA,
                                                             config: CONFIG, series: []) { |c| c }
        end

        assert_match(/closed spec/, error.message)
      end

      # -- the spec v1 freeze -------------------------------------------------

      def test_spec_v1_schema_is_frozen
        assert_equal 1, Spec::VERSION
        assert_equal %i[area bar line pie radar radial], Spec::TYPES
        assert_equal %i[key data_key name_key stack curve], Spec::SERIES_KEYS
        assert_equal %i[data_key hide tick_count format], Spec::AXIS_KEYS
      end
    end
  end
end
