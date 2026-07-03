# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL InputOTP markup driven by the REAL poetry--core--otp
  # projection. The defining moves: typed characters DISTRIBUTE into the
  # aria-hidden cells (slot[i] mirrors value[i]) and the active cell
  # advances with the caret; the pattern filter strips rejected chars and
  # splits pastes ("123-456" -> "123456") by writing BACK to the input;
  # truncation at length; poetry:otp:complete fires once per rise to full
  # and re-arms below it; blur clears the active cell. All of it via the
  # native input's own events - the controller has zero editing logic.
  class InputOtpBehaviorTest < TestCase
    def render_otp(**)
      html = render_inline(
        Poetry::Ui::InputOtp::Component.new(name: "code", length: 6, groups: [3, 3],
                                            "aria-label": "Verification code", **)
      ).to_html
      render_in_dommy(%(<form id="form">#{html}</form>))
    end

    def type(harness, value)
      harness.execute(<<~JS)
        const input = document.querySelector('[data-slot="input-otp"]');
        input.focus();
        input.value = #{value.to_json};
        input.dispatchEvent(new Event("input", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    # [painted chars, data-active flags, caret visibility] across slots.
    def cells(harness)
      harness.evaluate(<<~JS)
        (() => {
          const slots = Array.from(document.querySelectorAll('[data-slot="input-otp-slot"]'));
          return [
            slots.map((slot) => (slot.firstChild && slot.firstChild.nodeType === 3) ? slot.firstChild.data : "").join(""),
            slots.map((slot) => slot.getAttribute("data-active")).join(","),
            slots.map((slot) => slot.querySelector("[data-otp-caret]").hidden ? 0 : 1).join(",")
          ];
        })()
      JS
    end

    def input_value(harness)
      harness.evaluate('document.querySelector(\'[data-slot="input-otp"]\').value')
    end

    def test_typed_characters_distribute_into_the_cells_and_the_caret_advances
      harness = render_otp

      assert_no_js_errors harness

      type(harness, "1")

      assert_no_js_errors harness
      assert_equal ["1", "false,true,false,false,false,false", "0,1,0,0,0,0"], cells(harness),
                   "char 1 painted into cell 0; the active cell (with the fake caret) advanced to cell 1"

      type(harness, "123")

      assert_equal ["123", "false,false,false,true,false,false", "0,0,0,1,0,0"], cells(harness),
                   "the projection follows the native caret across the group boundary"
    end

    def test_pattern_rejected_chars_never_paint_and_pastes_split
      harness = render_otp

      type(harness, "12a!3")

      assert_no_js_errors harness
      assert_equal "123", input_value(harness), "the filter wrote the cleaned value BACK to the input"
      assert_equal "123", cells(harness).first

      # The canonical paste: an SMS code with a dash, under :digits.
      type(harness, "123-456")

      assert_equal "123456", input_value(harness), "paste splitting IS the filter line"
      assert_equal "123456", cells(harness).first

      type(harness, "12345678")

      assert_equal "123456", input_value(harness), "truncated at length"
    end

    def test_complete_fires_once_per_rise_and_rearms
      harness = render_otp
      harness.execute(<<~JS)
        window.__events = [];
        document.addEventListener("poetry:otp:change",
          (e) => window.__events.push(["change", e.detail.value, e.detail.complete]));
        document.addEventListener("poetry:otp:complete",
          (e) => window.__events.push(["complete", e.detail.value]));
      JS

      type(harness, "12345")
      type(harness, "123456")
      type(harness, "123456") # no mutation - no event
      type(harness, "12345")  # edit below length re-arms...
      type(harness, "123457") # ...so complete fires again

      assert_no_js_errors harness
      assert_equal [["change", "12345", false],
                    ["change", "123456", true], %w[complete 123456],
                    ["change", "12345", false],
                    ["change", "123457", true], %w[complete 123457]],
                   harness.evaluate("window.__events"),
                   "complete NEVER submits - it fires once per rise to full length"
    end

    def test_blur_clears_the_active_cell_and_the_server_value_paints_on_connect
      harness = render_otp(value: "12")

      assert_no_js_errors harness
      # Server-rendered chars adopted on connect; nothing active unfocused.
      assert_equal ["12", "false,false,false,false,false,false", "0,0,0,0,0,0"], cells(harness)

      type(harness, "12")

      assert_equal "false,false,true,false,false,false", cells(harness)[1], "focused: the caret cell activates"

      harness.execute(<<~JS)
        const input = document.querySelector('[data-slot="input-otp"]');
        input.blur();
        input.dispatchEvent(new Event("blur", { bubbles: false }));
      JS
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      assert_equal "false,false,false,false,false,false", cells(harness)[1], "blur clears data-active"
    end

    def test_the_complete_value_clamps_the_active_cell_to_the_last_slot
      harness = render_otp

      type(harness, "123456")

      assert_no_js_errors harness
      assert_equal "false,false,false,false,false,true", cells(harness)[1],
                   "the caret clamps to length-1 when full"
      assert_equal "0,0,0,0,0,0", cells(harness)[2], "a FILLED active cell shows the ring, never the caret"
    end
  end
end
