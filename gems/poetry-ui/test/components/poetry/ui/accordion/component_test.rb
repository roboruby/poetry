# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Accordion
      class ComponentTest < ViewComponent::TestCase
        def render_accordion(**options)
          render_inline(Component.new(**options)) do |accordion|
            accordion.with_item(value: "a", title: "First") { "panel a" }
            accordion.with_item(value: "b", title: "Second") { "panel b" }
          end.to_html
        end

        def test_renders_the_apg_structure
          html = render_accordion(open: %w[a])

          assert_includes html, 'data-component="accordion"'
          assert_includes html, 'data-controller="poetry--core--accordion poetry--core--roving-focus"'
          assert_includes html, 'data-poetry--core--roving-focus-manage-tabindex-value="false"'
          assert_match(/<h3[^>]*data-slot="accordion-header"[^>]*>\s*<button/, html)
          assert_match(/<div[^>]*role="region"[^>]*aria-labelledby="[^"]+-trigger"/, html)
        end

        def test_open_state_is_server_rendered
          html = render_accordion(open: %w[a])
          panel_a = html[/<div[^c]*?id="[^"]+-a-panel".*?>/m]
          panel_b = html[/<div[^c]*?id="[^"]+-b-panel".*?>/m]

          assert_match(/data-value="a"[^>]*data-open=""/, html)
          assert_match(/data-value="b"[^>]*data-closed=""/, html)
          assert_includes panel_b, %( hidden="hidden")
          refute_includes panel_a, %( hidden="hidden")
        end

        def test_single_non_collapsible_marks_the_open_trigger_aria_disabled
          html = render_accordion(open: %w[a])

          open_trigger = html[%r{data-value="a".*?</h3>}m]
          closed_trigger = html[%r{data-value="b".*?</h3>}m]

          assert_includes open_trigger, 'aria-disabled="true"'
          refute_includes closed_trigger, "aria-disabled"
          refute_includes render_accordion(collapsible: true, open: %w[a]), "aria-disabled"
        end

        def test_triggers_join_the_roving_collection_and_wire_toggle
          html = render_accordion

          assert_includes html, "data-poetry-collection-item"
          # The browser pass caught this missing: the roving keydown action
          # must be WIRED by the consumer - registration alone is deaf.
          assert_includes html, "keydown->poetry--core--roving-focus#keydown"
          assert_includes html, 'data-action="click->poetry--core--accordion#toggle"'
        end

        def test_heading_level_fits_the_outline
          html = render_inline(Component.new(heading_level: :h4)) do |accordion|
            accordion.with_item(value: "x", title: "T") { "p" }
          end.to_html

          assert_match(/<h4[^>]*data-slot="accordion-header"/, html)
        end

        def test_items_are_required_and_chevron_ships_built_in
          assert_raises(ArgumentError) { render_inline(Component.new) { "no items" } }
          assert_match(/data-slot="accordion-trigger".*?data-component="icon"/m, render_accordion,
                       "the indicator icon is built in")
        end
      end
    end
  end
end
