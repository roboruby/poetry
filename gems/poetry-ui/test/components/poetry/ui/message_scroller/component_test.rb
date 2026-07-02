# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module MessageScroller
      class ComponentTest < ViewComponent::TestCase
        def render_scroller(**, &)
          render_inline(Component.new(id: "chat", **), &).to_html
        end

        def test_renders_the_contract_surface
          html = render_scroller { "rows" }

          assert_includes html, 'data-component="message_scroller"'
          assert_includes html, 'data-controller="poetry--core--message-scroller"'
          %w[message-scroller message-scroller-viewport message-scroller-content
             message-scroller-spacer message-scroller-button].each do |slot|
            assert_includes html, %(data-slot="#{slot}"), slot
          end
        end

        def test_the_wrapper_opts_into_following_the_controller_does_not
          html = render_scroller { "x" }

          # The controller's default is the source-faithful false; poetry's
          # chat posture renders the value true explicitly.
          assert_includes html, 'data-poetry--core--message-scroller-auto-scroll-value="true"'
          assert_includes render_scroller(auto_scroll: false) { "x" },
                          'data-poetry--core--message-scroller-auto-scroll-value="false"'
        end

        def test_aria_contract
          html = render_scroller { "x" }

          assert_match(/<div[^>]*role="region"[^>]*tabindex="0"/, html)
          assert_match(/<div[^>]*role="log"[^>]*aria-relevant="additions"/, html)
          assert_match(/<div[^>]*data-slot="message-scroller-spacer"[^>]*aria-hidden="true"[^>]*hidden/, html)
        end

        def test_content_is_a_stable_stream_target
          assert_includes render_scroller { "x" }, 'id="chat-messages"'
        end

        def test_jump_button_is_a_poetry_button_wired_to_scroll_to_end
          html = render_scroller { "x" }

          assert_includes html, 'data-action="poetry--core--message-scroller#scrollToEnd"'
          assert_includes html, 'data-poetry--core--message-scroller-target="button"'
          assert_includes html, 'data-active="false"'
          assert_includes html, 'aria-label="Scroll to latest messages"'
          refute_includes render_scroller(jump_button: false) { "x" }, "message-scroller-button"
        end

        def test_all_values_flow_through_the_validated_builder
          html = render_scroller(default_scroll_position: :"last-anchor", track_visibility: true) { "x" }

          assert_includes html, 'data-poetry--core--message-scroller-default-scroll-position-value="last-anchor"'
          assert_includes html, 'data-poetry--core--message-scroller-track-visibility-value="true"'
        end
      end
    end
  end
end
