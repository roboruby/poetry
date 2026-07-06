# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end disclosure bar: the REAL NavigationMenu markup driven by the
  # REAL poetry--core--navigation-menu controller. The defining moves:
  # click opens one panel (vocabulary: aria-expanded + data-popup-open +
  # the presence pair), a second trigger SWITCHES (one open at a time), and
  # Escape closes + refocuses.
  class NavigationMenuBehaviorTest < TestCase
    def render_nav
      render_in_dommy(Poetry::Ui::NavigationMenu::Component.new(label: "Main")) do |nav|
        nav.with_item("Products", value: "products") { "products links" }
        nav.with_item("Solutions", value: "solutions") { "solutions links" }
        nav.with_link("Docs", href: "/docs")
      end
    end

    def click_trigger(harness, value)
      harness.execute(<<~JS)
        document.querySelector('[data-value="#{value}"] [data-slot="navigation-menu-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 10)
    end

    def state(harness, value)
      harness.evaluate(<<~JS)
        (() => {
          const item = document.querySelector('[data-value="#{value}"]');
          const trigger = item.querySelector('[data-slot="navigation-menu-trigger"]');
          const panel = item.querySelector('[data-slot="navigation-menu-content"]');
          return [trigger.getAttribute("aria-expanded"), trigger.hasAttribute("data-popup-open"),
                  panel.hidden];
        })()
      JS
    end

    def test_click_opens_one_panel_and_switching_closes_the_other
      harness = render_nav

      click_trigger(harness, "products")

      assert_no_js_errors harness
      assert_equal ["true", true, false], state(harness, "products")

      click_trigger(harness, "solutions")
      harness.pump(rounds: 80) # the closing panel rides the exit-animation timeout

      assert_equal ["true", true, false], state(harness, "solutions")
      assert_equal ["false", false, true], state(harness, "products"), "one panel at a time"
    end

    # -- the morphing shared viewport: panels ADOPT into the
    # shared positioner > popup > viewport on first activation; switching
    # keeps one open at a time across the adopted location; Escape closes
    # the whole composite. Geometry (the size/position morph + direction
    # stamps) needs real layout - the browser pass owns it.

    def render_viewport_nav
      render_in_dommy(Poetry::Ui::NavigationMenu::Component.new(label: "Main", viewport: true)) do |nav|
        nav.with_item("Products", value: "products") { "products links" }
        nav.with_item("Solutions", value: "solutions") { "solutions links" }
        nav.with_link("Docs", href: "/docs")
      end
    end

    def viewport_state(harness, value)
      harness.evaluate(<<~JS)
        (() => {
          const item = document.querySelector('[data-value="#{value}"]');
          const trigger = item.querySelector('[data-slot="navigation-menu-trigger"]');
          const panel = document.getElementById(trigger.getAttribute("aria-controls"));
          const viewport = document.querySelector('[data-slot="navigation-menu-viewport"]');
          return [trigger.getAttribute("aria-expanded"), panel.parentElement === viewport,
                  panel.hidden];
        })()
      JS
    end

    def shell_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const positioner = document.querySelector('[data-slot="navigation-menu-positioner"]');
          const popup = document.querySelector('[data-slot="navigation-menu-popup"]');
          return [positioner.hidden, popup.hasAttribute("data-open")];
        })()
      JS
    end

    def test_viewport_mode_adopts_panels_and_switches_one_at_a_time
      harness = render_viewport_nav
      click_trigger(harness, "products")

      assert_no_js_errors harness
      assert_equal ["true", true, false], viewport_state(harness, "products"),
                   "first activation adopts the panel into the shared viewport"
      assert_equal [false, true], shell_state(harness), "the shell opens with it"

      click_trigger(harness, "solutions")
      harness.pump(rounds: 80) # the outgoing panel rides the exit presence

      assert_equal ["true", true, false], viewport_state(harness, "solutions")
      assert_equal ["false", true, true], viewport_state(harness, "products"),
                   "the outgoing panel hides but STAYS adopted"
    end

    def test_escape_closes_the_viewport_composite
      harness = render_viewport_nav
      click_trigger(harness, "products")

      harness.execute(<<~JS)
        document.querySelector("nav").dispatchEvent(
          new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", true, true], viewport_state(harness, "products")
      assert_equal [true, false], shell_state(harness), "positioner hidden, popup closed"
    end

    def test_escape_closes_and_refocuses_the_trigger
      harness = render_nav
      click_trigger(harness, "products")

      harness.execute(<<~JS)
        document.querySelector("nav").dispatchEvent(
          new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      assert_equal ["false", false, true], state(harness, "products")
      focused = harness.evaluate("document.activeElement && document.activeElement.textContent.trim()")

      assert_equal "Products", focused, "Escape returns focus to the open trigger"
    end
  end
end
