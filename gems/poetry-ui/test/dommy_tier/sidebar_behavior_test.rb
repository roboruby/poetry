# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # End-to-end collapse machine: the REAL Sidebar shell driven by the REAL
  # poetry--core--sidebar controller. The defining moves: the trigger flips
  # data-state + data-collapsible on the peer (the CSS collapse hook) and
  # writes the cookie, and Cmd/Ctrl+B toggles from anywhere.
  class SidebarBehaviorTest < TestCase
    def render_shell(collapsible: :icon)
      render_in_dommy(Poetry::Ui::Sidebar::Component.new(collapsible: collapsible)) do |shell|
        shell.with_nav { "nav" }
        shell.with_inset { helper.poetry_sidebar_trigger }
      end
    end

    def helper
      @helper ||= ApplicationController.new.view_context
    end

    def peer_state(harness)
      harness.evaluate(<<~JS)
        (() => {
          const peer = document.querySelector('[data-slot="sidebar"]');
          return [peer.getAttribute("data-state"), peer.getAttribute("data-collapsible")];
        })()
      JS
    end

    def test_the_trigger_collapses_and_expands_the_peer
      harness = render_shell(collapsible: :icon)

      assert_no_js_errors harness
      assert_equal %w[expanded], peer_state(harness).compact.take(1)

      harness.execute(<<~JS)
        document.querySelector('[data-slot="sidebar-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      assert_equal %w[collapsed icon], peer_state(harness), "collapsed stamps the mode"

      harness.execute(<<~JS)
        document.querySelector('[data-slot="sidebar-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      assert_equal ["expanded", ""], peer_state(harness)
    end

    def test_the_keyboard_shortcut_toggles
      harness = render_shell

      harness.execute(<<~JS)
        window.dispatchEvent(new KeyboardEvent("keydown", { key: "b", metaKey: true, bubbles: true, cancelable: true }));
      JS
      harness.pump(rounds: 5)

      assert_no_js_errors harness
      assert_equal "collapsed", peer_state(harness).first
    end

    def test_the_persisted_cookie_records_the_choice
      harness = render_shell

      harness.execute(<<~JS)
        document.querySelector('[data-slot="sidebar-trigger"]')
          .dispatchEvent(new MouseEvent("click", { bubbles: true }));
      JS
      harness.pump(rounds: 5)

      cookie = harness.evaluate("document.cookie")

      assert_includes cookie, "sidebar_state=false", "the collapse is persisted for the server"
    end
  end
end
