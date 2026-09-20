# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end gesture machine: the REAL Drawer markup driven by the REAL
  # poetry--core--drawer controller. The defining moves: open rides the
  # starting-style two-frame trick, a drag writes the swipe CSS-var
  # contract onto the <dialog> (data-swiping + movement/progress), a short
  # release snaps back, a past-half release dismisses, and the trigger
  # wires the SUBCLASS controller (the lexical-CONTROLLER trap).
  class DrawerBehaviorTest < TestCase
    def render_drawer
      render_in_dommy(Poetry::Ui::Drawer::Component.new(show_swipe_handle: true)) do |drawer|
        drawer.with_trigger { "Open drawer" }
        drawer.with_title { "Move goal" }
        "drawer body"
      end
    end

    def open_drawer(harness)
      harness.execute(<<~JS)
        document.querySelector("button").dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def drag(harness, from_y:, to_y:, release: true)
      harness.execute(<<~JS)
        const dialog = document.querySelector("dialog");
        dialog.setPointerCapture ||= () => {};
        const handle = document.querySelector('[data-slot="drawer-swipe-handle"]');
        const fire = (type, target, y, time) => {
          const event = new MouseEvent(type, { bubbles: true, cancelable: true, clientY: y, button: 0 });
          Object.defineProperty(event, "pointerId", { value: 1 });
          Object.defineProperty(event, "pointerType", { value: "touch" });
          Object.defineProperty(event, "timeStamp", { value: time });
          target.dispatchEvent(event);
        };
        Object.defineProperty(dialog, "offsetHeight", { value: 400, configurable: true });
        fire("pointerdown", handle, #{from_y}, 0);
        fire("pointermove", dialog, #{(from_y + to_y) / 2}, 400);
        fire("pointermove", dialog, #{to_y}, 800);
        #{%(fire("pointerup", dialog, #{to_y}, 1200);) if release}
      JS
      harness.pump(rounds: 10)
    end

    def dialog_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const dialog = document.querySelector("dialog");
          return [dialog.hasAttribute("open"), dialog.hasAttribute("data-open"),
                  dialog.hasAttribute("data-swiping"),
                  dialog.style.getPropertyValue("--drawer-swipe-movement-y"),
                  dialog.style.getPropertyValue("--drawer-swipe-progress")];
        })()
      JS
    end

    def test_the_trigger_opens_through_the_subclass_controller
      harness = render_drawer
      open_drawer(harness)

      assert_no_js_errors harness
      open, data_open, swiping, movement, progress = dialog_state(harness)

      assert open
      assert data_open
      assert_not swiping
      assert_empty movement.to_s, "no swipe vars before any gesture"
      assert_empty progress.to_s
    end

    def test_a_drag_writes_the_swipe_contract_and_a_short_release_snaps_back
      harness = render_drawer
      open_drawer(harness)

      drag(harness, from_y: 100, to_y: 160, release: false)

      assert_no_js_errors harness
      open, _, swiping, movement, progress = dialog_state(harness)

      assert open
      assert swiping, "data-swiping rides the drag"
      assert_equal "60px", movement
      assert_equal "0.15", progress

      harness.execute(<<~JS)
        const dialog = document.querySelector("dialog");
        const event = new MouseEvent("pointerup", { bubbles: true, cancelable: true, clientY: 160 });
        Object.defineProperty(event, "pointerId", { value: 1 });
        Object.defineProperty(event, "timeStamp", { value: 5000 });
        dialog.dispatchEvent(event);
      JS
      harness.pump(rounds: 15)

      open, data_open, swiping, movement, = dialog_state(harness)

      assert open, "a short slow drag must not dismiss"
      assert data_open
      assert_not swiping
      assert_equal "0px", movement, "snapped home"
    end

    def test_a_past_half_release_dismisses_the_drawer
      harness = render_drawer
      open_drawer(harness)

      drag(harness, from_y: 100, to_y: 350)

      assert_no_js_errors harness
      open, data_open, = dialog_state(harness)

      assert_not open, "250px of 400 releases past the threshold - dismissed"
      assert_not data_open
    end
  end
end
