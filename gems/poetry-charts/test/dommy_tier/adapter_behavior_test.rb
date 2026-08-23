# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The adapter door end-to-end: a chart rendered with
  # engine: mounts through the REAL poetry--charts--adapter controller -
  # the registry lookup, the frozen spec handoff, the rendered dispatch
  # with declared degradations, and destroy on disconnect (the Turbo-away
  # contract). The chart mounts LATE (after the fake adapter registers),
  # which also proves Stimulus's MutationObserver-driven connect under
  # dommy - the same path a Turbo navigation takes.
  class AdapterBehaviorTest < TestCase
    DATA = [
      { month: "January", desktop: 186 },
      { month: "February", desktop: 305 }
    ].freeze

    CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze

    def adapter_chart_html
      render_inline(Poetry::Charts::AdapterChart::Component.new(
                      type: :bar, engine: "fake", data: DATA, config: CONFIG, id: "a",
                      series: [{ data_key: :desktop }], axes: { x: { data_key: :month } }
                    )).to_html
    end

    def mount_late(harness)
      harness.execute(<<~JS)
        globalThis.__adapterCalls = [];
        registerChartAdapter("fake", {
          degradations: ["no-html-tooltip"],
          render(mount, spec, helpers) {
            globalThis.__adapterCalls.push(["render", spec.type, spec.version]);
            mount.setAttribute("data-fake-rendered", "");
            return { token: 42 };
          },
          destroy(instance, mount) {
            globalThis.__adapterCalls.push(["destroy", instance.token]);
          },
        });
        document.addEventListener("poetry--charts--adapter:rendered", (event) => {
          globalThis.__adapterCalls.push(["rendered", event.detail.engine, event.detail.degradations]);
        });
        document.body.insertAdjacentHTML("beforeend", #{adapter_chart_html.to_json});
      JS
      harness.pump(rounds: 10)
    end

    def test_late_mount_renders_through_the_registered_adapter_and_destroys_on_removal
      harness = render_in_dommy("<div></div>")
      mount_late(harness)

      assert_no_js_errors harness
      calls = harness.evaluate("globalThis.__adapterCalls")

      assert_equal ["render", "bar", 1], calls[0], "the frozen spec v1 reached the adapter"
      assert_equal ["rendered", "fake", ["no-html-tooltip"]], calls[1],
                   "the rendered dispatch carries engine + declared degradations"
      assert harness.evaluate(
        %(document.querySelector('[data-slot="chart-adapter-mount"]').hasAttribute("data-fake-rendered"))
      )

      harness.execute(%(document.querySelector('[data-controller~="poetry--charts--adapter"]').remove();))
      harness.pump(rounds: 10)

      assert_equal ["destroy", 42], harness.evaluate("globalThis.__adapterCalls").last,
                   "removal disconnects through the adapter's destroy (the Turbo-away contract)"
      assert_no_js_errors harness
    end

    def test_an_unregistered_engine_fails_loudly_not_silently
      harness = render_in_dommy(adapter_chart_html) # boots with NO fake adapter registered

      assert(harness.logs.any? { |log| log.to_s.include?("no adapter registered") },
             "the console error names the missing engine (got: #{harness.logs.inspect})")
    end
  end
end
