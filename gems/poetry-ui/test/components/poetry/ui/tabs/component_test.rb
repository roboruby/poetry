# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Tabs
      class ComponentTest < ViewComponent::TestCase
        def render_tabs(**, &block)
          block ||= lambda { |tabs|
            tabs.with_tab("Account", value: "account") { "account panel" }
            tabs.with_tab("Password", value: "password") { "password panel" }
          }
          render_inline(Component.new(**), &block)
        end

        def test_the_aria_wiring_is_complete_and_cross_referenced
          html = render_tabs(label: "Settings")

          list = html.css('[role="tablist"]').first

          assert_equal "Settings", list["aria-label"]
          triggers = html.css('[role="tab"]')
          panels = html.css('[role="tabpanel"]')

          assert_equal 2, triggers.length
          assert_equal 2, panels.length
          triggers.zip(panels).each do |trigger, panel|
            assert_equal panel["id"], trigger["aria-controls"]
            assert_equal trigger["id"], panel["aria-labelledby"]
          end
        end

        def test_the_server_renders_the_active_tab_without_js
          html = render_tabs

          active = html.css('[role="tab"][data-active]').first

          assert_equal "Account", active.text.strip, "the first enabled tab is the default"
          assert_equal "true", active["aria-selected"]
          assert_equal "0", active["tabindex"]
          visible = html.css('[role="tabpanel"]:not([hidden])')

          assert_equal 1, visible.length
          assert_equal "account panel", visible.first.text.strip
        end

        def test_default_picks_the_active_tab_and_hides_the_rest
          html = render_tabs(default: "password")

          assert_equal "Password", html.css('[role="tab"][data-active]').first.text.strip
          hidden = html.css('[role="tabpanel"][hidden]').first

          assert hidden["data-hidden"], "inactive panels wear the Base UI data-hidden"
          assert_equal "account panel", hidden.text.strip
        end

        def test_an_unknown_default_raises
          error = assert_raises(ArgumentError) { render_tabs(default: "nope") }

          assert_match(/matches no tab value/, error.message)
        end

        def test_a_disabled_tab_is_skipped_as_the_default_and_filtered_for_roving
          html = render_inline(Component.new) do |tabs|
            tabs.with_tab("Locked", value: "locked", disabled: true) { "locked" }
            tabs.with_tab("Open", value: "open") { "open" }
          end

          assert_equal "Open", html.css('[role="tab"][data-active]').first.text.strip
          locked = html.css('[role="tab"]').first

          assert locked["disabled"]
          assert locked["data-disabled"], "the roving-focus collection filter"
        end

        def test_panel_false_declares_a_list_only_tab
          html = render_inline(Component.new) do |tabs|
            tabs.with_tab("Overview", value: "overview", panel: false)
            tabs.with_tab("Analytics", value: "analytics", panel: false)
          end

          # No tabpanel renders and the trigger drops aria-controls (there
          # is no id to reference) - upstream's list-only demo shape.
          assert_empty html.css('[role="tabpanel"]')
          html.css('[role="tab"]').each { |trigger| assert_nil trigger["aria-controls"] }
        end

        def test_a_tab_without_panel_defer_or_optout_still_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new) { |tabs| tabs.with_tab("Bare", value: "bare") }
          end

          assert_match(/panel block, defer:, or panel: false/, error.message)
        end

        def test_the_two_controller_split_is_wired
          html = render_tabs

          root = html.css('[data-slot="tabs"]').first

          assert_includes root["data-controller"], "poetry--core--tabs"
          list = html.css('[data-slot="tabs-list"]').first

          assert_includes list["data-controller"], "poetry--core--roving-focus"
          assert_includes list["data-action"], "keydown->poetry--core--roving-focus#keydown"
          assert_includes list["data-action"], "poetry--core--roving-focus:entry->poetry--core--tabs#focusActivate"
          assert_equal "horizontal", list["data-poetry--core--roving-focus-orientation-value"]
          trigger = html.css('[role="tab"]').first

          assert_includes trigger["data-action"], "click->poetry--core--tabs#activate"
          assert trigger["data-poetry-collection-item"], "triggers are the roving collection"
        end

        def test_the_line_variant_and_orientation_ride_the_list
          html = render_tabs(variant: :line, orientation: :vertical)

          root = html.css('[data-slot="tabs"]').first

          assert_equal "vertical", root["data-orientation"]
          list = html.css('[data-slot="tabs-list"]').first

          assert_equal "line", list["data-variant"]
          assert_includes list["class"], "cn-tabs-list-variant-line"
          assert_equal "vertical", list["aria-orientation"]
        end

        def test_tabs_require_at_least_one_tab
          assert_raises(ArgumentError) { render_inline(Component.new) }
        end
      end
    end
  end
end
