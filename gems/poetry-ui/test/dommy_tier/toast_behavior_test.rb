# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL Toast/Toaster markup driven by the REAL poetry--core--toast +
  # poetry--core--toaster controllers and the announce SINGLETON: the
  # toaster acquires the lazily-created sr-only live regions on body; the
  # item (role=status aria-live=OFF - it never self-announces) speaks
  # exactly ONCE through the polite/assertive region at its politeness;
  # the close button dismisses through data-state=closed -> presence ->
  # REMOVAL; the toaster writes the stack reflow index. Live-region
  # ANNOUNCEMENT fidelity (what a screen reader actually says), timer
  # feel, and the F8 focus journey stay with the real-browser pass - the
  # jsdom-invisible bug surface the contract flags.
  class ToastBehaviorTest < TestCase
    def render_toaster_with(*toasts)
      items = toasts.map { |toast| render_inline(toast).to_html }.join.html_safe
      component = Poetry::Ui::Toaster::Component.new
      component.with_content(items)
      render_in_dommy(component)
    end

    def toast(variant: :default, title: "Changes saved", description: nil)
      Poetry::Ui::Toast::Component.new(variant: variant).tap do |component|
        component.with_title { title }
        component.with_description { description } if description
      end
    end

    def region_text(harness, politeness)
      harness.evaluate(
        %(document.querySelector('[data-poetry-announce-region="#{politeness}"]')?.textContent ?? null)
      )
    end

    def test_the_singleton_announces_the_item_once_politely
      harness = render_toaster_with(toast(description: "Profile updated."))
      harness.pump(rounds: 30) # the clear-then-set microtask + queue gap

      assert_no_js_errors harness

      # The regions are LAZY (created on first use, refcounted by the
      # toaster) and sr-only on body - not server markup.
      assert_equal "polite",
                   harness.evaluate(
                     %(document.querySelector('[data-poetry-announce-region="polite"]').getAttribute("aria-live"))
                   )
      assert_equal "Changes saved Profile updated.", region_text(harness, "polite"),
                   "title + description spoken ONCE through the singleton"
      assert_equal "", region_text(harness, "assertive")

      # The item itself stays muted - role=status aria-live=off.
      assert_equal %w[status off],
                   harness.evaluate(<<~JS)
                     (() => {
                       const item = document.querySelector('[data-slot="toast"]');
                       return [item.getAttribute("role"), item.getAttribute("aria-live")];
                     })()
                   JS
    end

    def test_destructive_routes_to_the_assertive_region
      harness = render_toaster_with(toast(variant: :destructive, title: "Payment failed"))
      harness.pump(rounds: 30)

      assert_no_js_errors harness
      assert_equal "Payment failed", region_text(harness, "assertive")
      assert_equal "", region_text(harness, "polite")
    end

    def test_close_dismisses_through_presence_removal_and_reflow
      harness = render_toaster_with(toast(title: "First"), toast(title: "Second"))
      harness.pump(rounds: 10)

      # The toaster's reflow stamps the stack index (newest = 0).
      assert_equal %w[1 0],
                   harness.evaluate(<<~JS)
                     [...document.querySelectorAll('[data-slot="toast"]')]
                       .map((item) => item.style.getPropertyValue("--poetry-toast-index"))
                   JS

      harness.execute(<<~JS)
        document.querySelector('[data-slot="toast"] [data-slot="toast-close"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      # The exit rides presence's animationend/timeout fallback, then the
      # node is REMOVED (not hidden) and the stack re-indexes.
      harness.pump(rounds: 80)

      assert_no_js_errors harness
      remaining = harness.evaluate(<<~JS)
        [...document.querySelectorAll('[data-slot="toast"]')]
          .map((item) => [item.querySelector('[data-slot="toast-title"]').textContent.trim(),
                          item.style.getPropertyValue("--poetry-toast-index")])
      JS

      assert_equal [%w[Second 0]], remaining, "close removes the toast; the survivor re-indexes to the front"
    end

    def test_the_limit_queues_overflow_hidden_with_timers_held
      harness = render_toaster_with(toast(title: "One"), toast(title: "Two"),
                                    toast(title: "Three"), toast(title: "Four"))
      harness.pump(rounds: 10)

      assert_no_js_errors harness
      states = harness.evaluate(<<~JS)
        [...document.querySelectorAll('[data-slot="toast"]')]
          .map((item) => [item.querySelector('[data-slot="toast-title"]').textContent.trim(),
                          item.hidden, item.hasAttribute("data-queued")])
      JS

      # limit 3: the OLDEST overflows into the hidden queue (its timer
      # held by the "queued" pause) until a slot frees up.
      assert_equal [["One", true, true], ["Two", false, false],
                    ["Three", false, false], ["Four", false, false]], states
    end
  end
end
