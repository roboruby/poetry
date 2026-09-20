# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Collapsible
      class ComponentTest < ViewComponent::TestCase
        def render_collapsible(**)
          render_inline(Component.new(**)) do |collapsible|
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

        # The wiring blocks below build markup the way a view would.
        def tag = ActionController::Base.helpers.tag

        def test_wiring_block_composes_a_custom_trigger
          html = render_inline(Component.new) do |collapsible|
            collapsible.with_trigger(compose: true) do |wiring|
              tag.a("Toggle", href: "#", class: "custom-trigger", **wiring)
            end
            "Body"
          end.to_html
          fragment = Nokogiri::HTML.fragment(html)
          trigger = fragment.css("a.custom-trigger").first

          assert trigger, "the block's markup renders as the trigger"
          assert_equal "false", trigger["aria-expanded"]
          assert_includes trigger["data-action"].to_s, "state#toggle"
          assert_equal "collapsible-trigger", trigger["data-slot"]
        end
      end
    end
  end
end
