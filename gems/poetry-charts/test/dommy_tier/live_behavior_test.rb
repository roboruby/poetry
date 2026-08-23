# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The live channel end-to-end ON THE KERNEL: a live: true chart's two
  # channels (the poetry-chart:update event API and the payload-script
  # replacement a turbo_stream.update performs - dommy 0.9 ships a real
  # MutationObserver) trigger the vendored @poetry/charts/d3 renderer -
  # scales, stacks, nice ticks, path strings - running under QuickJS
  # against the server-rendered SVG. This is the tier's flagship proof:
  # the byte-parity kernel (vitest proves it equals the Ruby engine)
  # actually executing on a non-V8 engine with in-place attribute updates.
  # The FLIP tween rides the harness's pumped rAF clock to settled.
  class LiveBehaviorTest < TestCase
    DATA = [
      { month: "January", desktop: 186, mobile: 80 },
      { month: "February", desktop: 305, mobile: 200 },
      { month: "March", desktop: 237, mobile: 120 }
    ].freeze

    NEXT_DATA = [
      { month: "January", desktop: 40, mobile: 300 },
      { month: "February", desktop: 500, mobile: 60 },
      { month: "March", desktop: 120, mobile: 210 }
    ].freeze

    CONFIG = {
      desktop: { label: "Desktop", color: "var(--chart-1)" },
      mobile: { label: "Mobile", color: "var(--chart-2)" }
    }.freeze

    def chart(legend: false)
      Poetry::Charts::AreaChart::Component.new(data: DATA, config: CONFIG, id: "lv",
                                               live: true).tap do |component|
        component.with_x_axis(data_key: :month)
        component.with_area(data_key: :desktop)
        component.with_area(data_key: :mobile)
        component.with_tooltip
        component.with_legend(toggle: true) if legend
      end
    end

    def area_path(harness, key)
      harness.evaluate(%(document.querySelector('path[data-slot="chart-area"][data-key="#{key}"]')
        .getAttribute("d")))
    end

    def test_the_event_api_rerenders_through_the_kernel_and_settles
      harness = render_in_dommy(chart)

      assert_no_js_errors harness
      before = area_path(harness, "desktop")

      harness.execute(<<~JS)
        document.querySelector('[data-controller~="poetry--charts--live"]').dispatchEvent(
          new CustomEvent("poetry-chart:update", { detail: { data: #{NEXT_DATA.to_json} } }));
      JS
      # The FLIP tween rides the pumped clock: 1500ms at 16ms steps.
      harness.pump(rounds: 110)

      assert_no_js_errors harness
      after = area_path(harness, "desktop")

      refute_equal before, after, "the kernel recomputed the area path in place"
      payload = JSON.parse(harness.evaluate(
                             %(document.querySelector('[data-slot="chart-live-payload"]').textContent)
                           ))

      assert_equal 500, payload.dig("spec", "data", 1, "desktop"),
                   "the payload script always holds current state"
      motion = harness.evaluate(%(document.querySelector('[data-slot="chart-svg"]').getAttribute("data-motion")))

      assert_equal "settled", motion, "the tween ran to settle on the pumped rAF clock"
    end

    def test_the_script_replacement_channel_rerenders_what_a_turbo_stream_writes
      harness = render_in_dommy(chart)
      before = area_path(harness, "desktop")

      # Exactly what a turbo_stream.update of the payload script does: new
      # JSON in the script tag, no event - the MutationObserver channel.
      harness.execute(<<~JS)
        const script = document.querySelector('[data-slot="chart-live-payload"]');
        const payload = JSON.parse(script.textContent);
        payload.spec.data = #{NEXT_DATA.to_json};
        script.textContent = JSON.stringify(payload);
      JS
      harness.pump(rounds: 110)

      assert_no_js_errors harness
      refute_equal before, area_path(harness, "desktop"),
                   "the payload-script channel rendered without any event"
    end

    def test_the_tooltip_serves_fresh_values_mid_stream
      harness = render_in_dommy(chart)

      harness.execute(<<~JS)
        document.querySelector('[data-slot="chart-svg"]').dispatchEvent(
          new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 5)

      harness.execute(<<~JS)
        document.querySelector('[data-controller~="poetry--charts--live"]').dispatchEvent(
          new CustomEvent("poetry-chart:update", { detail: { data: #{NEXT_DATA.to_json} } }));
      JS
      harness.pump(rounds: 110)

      assert_no_js_errors harness
      state = harness.evaluate(<<~JS)
        (() => {
          const tooltip = document.querySelector('[data-slot="chart-tooltip"]');
          const value = tooltip.querySelector('[data-slot="chart-tooltip-item"][data-key="desktop"] ' +
            '[data-slot="chart-tooltip-value"]');
          return [tooltip.hidden, value.textContent];
        })()
      JS

      assert_equal [false, "40"], state,
                   "live:updated re-read the regenerated coordinates and kept the active index"
    end

    def test_set_window_slices_the_full_data_and_renders_instantly
      harness = render_in_dommy(chart)
      before = area_path(harness, "desktop")

      # The window seam (the brush/zoom controllers call this; the
      # drag geometry itself is browser-pass territory): [start, end]
      # inclusive indices into the FULL data, rendered without a tween so
      # a drag tracks the pointer.
      harness.execute(<<~JS)
        const frame = document.querySelector('[data-controller~="poetry--charts--live"]');
        window.__poetryApp.getControllerForElementAndIdentifier(frame, "poetry--charts--live")
          .setWindow([0, 1]);
      JS
      harness.pump(rounds: 5)

      assert_no_js_errors harness
      refute_equal before, area_path(harness, "desktop"), "the window slice recomputed the geometry"
      assert_equal [0, 1],
                   JSON.parse(harness.evaluate(
                                %(document.querySelector('[data-slot="chart-live-payload"]').textContent)
                              )).dig("frame", "window")
    end

    def test_legend_toggle_rescales_the_domain_and_hides_the_series_marks
      harness = render_in_dommy(chart(legend: true))
      before = area_path(harness, "mobile")

      # Hide DESKTOP - the series holding the domain max, so the survivor's
      # geometry must rescale (hiding the smaller one would be a no-op).
      harness.execute(<<~JS)
        document.querySelector('button[data-slot="chart-legend-item"][data-key="desktop"]').click();
      JS
      harness.pump(rounds: 110)

      assert_no_js_errors harness

      hidden_mark = harness.evaluate(
        %(document.querySelector('path[data-slot="chart-area"][data-key="desktop"]').style.display)
      )

      assert_equal "none", hidden_mark, "the hidden series' marks toggle display, DOM intact"
      assert_equal ["desktop"],
                   JSON.parse(harness.evaluate(
                                %(document.querySelector('[data-slot="chart-live-payload"]').textContent)
                              )).dig("frame", "hidden")
      refute_equal before, area_path(harness, "mobile"),
                   "the surviving series rescaled (recharts' rescale-on-hide)"

      dimmed = harness.evaluate(
        %(document.querySelector('button[data-slot="chart-legend-item"][data-key="desktop"]')
          .hasAttribute("data-hidden"))
      )

      assert dimmed, "the toggled legend item dims"
    end
  end
end
