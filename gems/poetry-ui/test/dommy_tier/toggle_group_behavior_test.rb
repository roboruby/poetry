# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL ToggleGroup markup driven by the REAL poetry--core--toggle-group
  # value machine + poetry--core--roving-focus (default tabindex-managing
  # mode) on one root. Single mode's defining moves: exclusivity (pressing
  # b unpresses a), deselect-to-empty on re-press (Radix setValue('')), the
  # aria-checked vocabulary with aria-pressed NEVER written, and the
  # pressed item becoming the roving tab stop. Multiple mode is the XOR
  # machine wearing aria-pressed.
  class ToggleGroupBehaviorTest < TestCase
    def render_group(**options)
      render_in_dommy(Poetry::Ui::ToggleGroup::Component.new(label: "Formatting", **options)) do |group|
        group.with_item(value: "bold", label: "Toggle bold") { "B" }
        group.with_item(value: "italic", label: "Toggle italic") { "I" }
        group.with_item(value: "underline", label: "Toggle underline") { "U" }
      end
    end

    # [data-state, aria-checked, aria-pressed, tabindex] per item value.
    def items_state(harness)
      harness.evaluate(<<~JS)
        (() => Array.from(document.querySelectorAll('[data-slot="toggle-group-item"]')).map((item) => [
          item.dataset.value, item.dataset.state,
          item.getAttribute("aria-checked"), item.getAttribute("aria-pressed"),
          item.getAttribute("tabindex")
        ]))()
      JS
    end

    def click_item(harness, value)
      harness.execute(<<~JS)
        document.querySelector('[data-slot="toggle-group-item"][data-value="#{value}"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def test_single_mode_exclusivity_deselect_to_empty_and_the_roving_tab_stop
      harness = render_group(type: :single, value: "bold")

      assert_no_js_errors harness
      # Server truth reconciled on connect; roving stamps ONE tab stop and
      # the group controller prefers the pressed item (active=pressed).
      assert_equal [["bold", "on", "true", nil, "0"],
                    ["italic", "off", "false", nil, "-1"],
                    ["underline", "off", "false", nil, "-1"]], items_state(harness)

      harness.execute(<<~JS)
        window.__changes = [];
        document.addEventListener("poetry:toggle-group:change",
          (event) => window.__changes.push([event.detail.value, event.detail.pressed, event.detail.unpressed]));
      JS
      click_item(harness, "italic")

      assert_no_js_errors harness
      # Exclusivity: pressing italic unpresses bold; the vocabulary stays
      # radio-only (aria-pressed never appears) and the tab stop follows.
      assert_equal [["bold", "off", "false", nil, "-1"],
                    ["italic", "on", "true", nil, "0"],
                    ["underline", "off", "false", nil, "-1"]], items_state(harness)

      click_item(harness, "italic")

      # Deselect-to-empty (Radix setValue('')): |S| = 0 is legal for
      # single; exactly ONE tab stop survives (falls back to the first
      # enabled item).
      assert_equal [["bold", "off", "false", nil, "0"],
                    ["italic", "off", "false", nil, "-1"],
                    ["underline", "off", "false", nil, "-1"]], items_state(harness)
      assert_equal [["italic", ["italic"], ["bold"]], [nil, [], ["italic"]]],
                   harness.evaluate("window.__changes")
    end

    def test_multiple_mode_is_an_independent_xor_machine_wearing_aria_pressed
      harness = render_group(type: :multiple, values: %w[bold])

      assert_no_js_errors harness
      assert_equal [["bold", "on", nil, "true", "0"],
                    ["italic", "off", nil, "false", "-1"],
                    ["underline", "off", nil, "false", "-1"]], items_state(harness)

      click_item(harness, "underline")

      assert_no_js_errors harness
      # XOR: bold stays pressed - no exclusivity in toolbar mode; the
      # vocabulary stays toggle-button-only (aria-checked never appears).
      assert_equal(%w[on off on], items_state(harness).map { |item| item[1] })
      assert_equal(%w[true false true], items_state(harness).map { |item| item[3] })
      assert_equal([nil, nil, nil], items_state(harness).map { |item| item[2] })

      click_item(harness, "bold")

      assert_equal(%w[off off on], items_state(harness).map { |item| item[1] })
    end

    def test_arrow_keys_move_the_single_tab_stop_without_selecting
      harness = render_group(type: :single, value: "bold")

      harness.execute(<<~JS)
        const first = document.querySelector('[data-slot="toggle-group-item"][data-value="bold"]');
        first.focus();
        first.dispatchEvent(new KeyboardEvent("keydown",
          { key: "ArrowRight", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      focused = harness.evaluate("document.activeElement && document.activeElement.dataset.value")

      assert_equal "italic", focused, "arrows move focus (roving)"
      # ...WITHOUT selecting (the deliberate Radix deviation from APG
      # radio's move-selects: browsing options never fires effects).
      assert_equal(%w[on off off], items_state(harness).map { |item| item[1] })
    end
  end
end
