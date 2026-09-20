# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The chart-spec: closed and versioned. Unknown keys raise (an open
    # options bag would leak engine keys - designed out), the wire format is
    # camelCase recharts vocabulary, and every spec carries its version.
    class SpecTest < ActiveSupport::TestCase
      DATA = [{ month: "Jan", desktop: 186 }, { month: "Feb", desktop: 305 }].freeze

      def build(**overrides)
        Spec.new(
          type: :area,
          data: DATA,
          series: [{ data_key: :desktop, stack: "a" }],
          axes: { x: { data_key: :month } },
          config: { desktop: { label: "Desktop", color: "var(--chart-1)" } },
          **overrides
        )
      end

      def test_serializes_versioned_camel_case_wire_format
        wire = build.to_h

        assert_equal 1, wire["version"]
        assert_equal "area", wire["type"]
        assert_equal({ "month" => "Jan", "desktop" => 186 }, wire["data"].first)
        assert_equal "desktop", wire["series"].first["dataKey"]
        assert_equal "a", wire["series"].first["stack"]
        assert_equal "month", wire["axes"]["x"]["dataKey"]
        assert_equal "Desktop", wire["config"]["desktop"]["label"]
      end

      def test_to_json_round_trips
        parsed = JSON.parse(build.to_json)

        assert_equal 1, parsed["version"]
        assert_equal 2, parsed["data"].length
      end

      def test_rejects_unknown_chart_types
        assert_raises(ArgumentError) { build(type: :treemap) }
      end

      def test_the_spec_is_closed_on_series_keys
        error = assert_raises(ArgumentError) do
          build(series: [{ data_key: :desktop, library: { engine: "stuff" } }])
        end

        assert_match(/closed/, error.message)
      end

      def test_the_spec_is_closed_on_axis_keys
        assert_raises(ArgumentError) { build(axes: { x: { data_key: :month, tick_color: "red" } }) }
      end

      def test_series_require_a_data_key
        assert_raises(ArgumentError) { build(series: [{ stack: "a" }]) }
      end
    end
  end
end
