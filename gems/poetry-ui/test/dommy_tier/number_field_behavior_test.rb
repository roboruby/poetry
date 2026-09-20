# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL NumberField markup under the real controller: the
  # two-input pair stays in sync (visible formatted text, hidden raw
  # number), stepper clicks step and reflect boundary disabling, and
  # ArrowUp/Down on the input step with commit events.
  class NumberFieldBehaviorTest < TestCase
    def render_number_field(**)
      html = render_inline(Poetry::Ui::NumberField::Component.new(name: "quantity", **)).to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    def state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const root = document.querySelector('[data-slot="number-field"]');
          return [
            document.querySelector('[data-slot="input-group-control"]').value,
            document.querySelector('input[type="number"]').value,
            root.hasAttribute("data-filled"),
            document.querySelector('[data-slot="number-field-increment"]').disabled
          ];
        })()
      JS
    end

    def click(harness, slot)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="#{slot}"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_stepper_clicks_step_both_inputs_and_disable_at_the_bound
      harness = render_number_field(value: 4, min: 0, max: 5)

      click(harness, "number-field-increment")

      assert_equal ["5", "5", true, true], state(harness)

      click(harness, "number-field-decrement")

      assert_equal ["4", "4", true, false], state(harness)
    end

    def test_arrow_keys_step_from_the_input_and_commit
      harness = render_number_field(value: 10)
      harness.execute(<<~JS)
        window.commits = [];
        document.querySelector('[data-slot="number-field"]')
          .addEventListener("poetry:number-field:commit", (e) => window.commits.push(e.detail.value));
        document.querySelector('[data-slot="input-group-control"]')
          .dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_equal ["11", "11", true, false], state(harness)
      assert_equal [11], harness.evaluate("window.commits")
    end

    def test_currency_format_displays_formatted_but_submits_raw
      harness = render_number_field(value: 1234.5, format: { style: "currency", currency: "USD" },
                                    locale: "en-US")

      display, raw, filled, = state(harness)

      # dommy's Intl carries minimal ICU (currency renders as "USD" there,
      # "$" in real browsers) - assert the invariant, not the symbol.
      assert_includes display, "1,234.50"
      refute_equal raw, display
      assert_equal "1234.5", raw
      assert filled
    end
  end
end
