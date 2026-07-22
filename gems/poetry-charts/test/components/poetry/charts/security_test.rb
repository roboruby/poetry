# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # Chart data is embedded as JSON in `<script type="application/json">`
    # islands read by the Stimulus controllers. A `</script>` sequence closes
    # a script element regardless of its `type`, so a user-controlled label,
    # category, or value carrying one would break out of the island into live
    # HTML unless it is escaped. `script_json` (Poetry::Core::Component)
    # escapes it INDEPENDENT of the host's
    # `ActiveSupport.escape_html_entities_in_json` flag - these tests pin that
    # guarantee with the flag forced OFF (the worst case a host can set).
    class SecurityTest < ViewComponent::TestCase
      PAYLOAD = "</script><svg onload=alert(1)>"

      # Force the host's HTML-in-JSON escaping OFF for the block, then restore.
      def without_html_json_escaping
        mod = ActiveSupport::JSON::Encoding
        prior = mod.escape_html_entities_in_json
        mod.escape_html_entities_in_json = false
        yield
      ensure
        mod.escape_html_entities_in_json = prior
      end

      def script_islands(html)
        html.css('script[type="application/json"]')
      end

      def test_script_json_escapes_breakout_chars_regardless_of_host_flag
        helper = Class.new(Poetry::Core::Component).new
        without_html_json_escaping do
          out = helper.script_json({ "label" => PAYLOAD }.to_json)

          refute_includes out, "</script>", "the island must not contain a literal </script>"
          refute_includes out, "<svg", "no literal markup may survive into the island"
          assert_equal PAYLOAD, JSON.parse(out)["label"], "JSON.parse still recovers the original value"
        end
      end

      def test_script_json_is_a_noop_when_the_host_already_escapes
        helper = Class.new(Poetry::Core::Component).new
        already_escaped = { "label" => PAYLOAD }.to_json # flag ON by default -> <...

        assert_equal already_escaped, helper.script_json(already_escaped),
                     "already-escaped JSON must pass through untouched (idempotent)"
      end

      def test_pie_coordinate_island_never_breaks_out_of_its_script_tag
        config = {
          visitors: { label: "Visitors" },
          chrome: { label: PAYLOAD, color: "var(--chart-1)" },
          safari: { label: "Safari", color: "var(--chart-2)" }
        }
        data = [
          { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
          { browser: "safari", visitors: 200, fill: "var(--color-safari)" }
        ]

        without_html_json_escaping do
          html = render_inline(PieChart::Component.new(data: data, config: config, id: "sec")) do |chart|
            chart.with_pie(data_key: :visitors, name_key: :browser)
            chart.with_tooltip
          end

          islands = script_islands(html)

          assert_predicate islands, :any?, "the pie renders at least one JSON island"

          islands.each do |island|
            text = island.text

            refute_includes text, "</script>", "island text must not carry a literal </script> breakout"
            refute_includes text, "<svg", "island text must not carry literal markup"
            assert_nothing_raised { JSON.parse(text) }
          end

          # And the malicious label survives as DATA (escaped, not dropped).
          coords = islands.map(&:text).find do |t|
            t.include?("chrome") || t.include?("Visitors") || t.include?("\\u003c")
          end

          assert coords, "the coordinate island is present"
          assert_includes JSON.parse(coords).to_s, PAYLOAD, "the label round-trips through JSON.parse intact"
        end
      end

      def test_chart_id_is_reduced_to_a_safe_dom_token
        html = render_inline(PieChart::Component.new(data: [{ browser: "a", visitors: 1, fill: "x" }],
                                                     config: { visitors: { label: "V" }, a: { label: "A" } },
                                                     id: "evil</style><script>alert(1)</script>")) do |chart|
          chart.with_pie(data_key: :visitors, name_key: :browser)
        end

        refute_includes html.to_html, "</style><script>", "a user-controlled id must not break out of <style>"
      end
    end
  end
end
