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
