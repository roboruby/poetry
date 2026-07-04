# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Collapsible
      class ComponentTest < ViewComponent::TestCase
        def render_collapsible(**options)
          render_inline(Component.new(**options)) do |collapsible|
            collapsible.with_trigger { "Show" }
            collapsible.with_content("details")
          end.to_html
        end

        def test_renders_the_disclosure_contract
          html = render_collapsible

          assert_includes html, 'data-component="collapsible"'
          assert_includes html, 'data-controller="poetry--core--state"'
          assert_match(/<button[^>]*data-slot="collapsible-trigger"/, html)
          assert_match(/<button[^>]*type="button"/, html)
          assert_includes html, 'data-action="click->poetry--core--state#toggle"'
          assert_includes html, 'data-poetry--core--state-target="trigger"'
          assert_includes html, 'data-poetry--core--state-target="content"'
        end

        def test_closed_by_default_with_wired_aria
          html = render_collapsible
          controls = html[/aria-controls="([^"]+)"/, 1]

          assert_includes html, 'aria-expanded="false"'
          assert_includes html, 'data-closed=""'
          assert_includes html, %(id="#{controls}")
          assert_match(/<div[^>]*id="#{controls}"[^>]*hidden/, html)
        end

        def test_open_server_renders_visible
          html = render_collapsible(open: true)

          assert_includes html, 'aria-expanded="true"'
          refute_match(/<div[^>]*data-slot="collapsible-content"[^>]*hidden/, html)
        end

        def test_trigger_is_required
          assert_raises(ArgumentError) { render_inline(Component.new) { "content only" } }
        end
      end
    end
  end
end
