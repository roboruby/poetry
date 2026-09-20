# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Message
      class ComponentTest < ViewComponent::TestCase
        def test_renders_the_contract_surface
          html = render_inline(Component.new) do |message|
            message.with_avatar { "AI" }
            message.with_header { "Assistant" }
            message.with_footer { "10:41" }
            message.with_content("body")
          end.to_html

          assert_includes html, 'data-component="message"'
          assert_includes html, 'data-align="start"'
          %w[message-avatar message-content message-header message-footer].each do |slot|
            assert_includes html, %(data-slot="#{slot}"), slot
          end
        end

        def test_align_end_reverses_the_row
          html = render_inline(Component.new(align: :end)) { "x" }.to_html

          assert_includes html, 'data-align="end"'
          assert_includes html, "data-[align=end]:flex-row-reverse"
        end

        def test_footer_presence_lifts_the_avatar_via_css_context
          html = render_inline(Component.new) { "x" }.to_html

          # The :has() context selector ships in the avatar element classes
          # (the cross-part coupling the contract documents).
          assert_includes Style.css(:avatar), "group-has-data-[slot=message-footer]/message:-translate-y-8"
          # The ghost padding collapse rides .cn-message-header in the theme.
          assert_includes Style.css(:header), "cn-message-header"
          assert_includes html, 'data-slot="message"'
        end

        def test_optional_slots_render_nothing_when_absent
          html = render_inline(Component.new) { "just the body" }.to_html

          refute_includes html, "message-avatar"
          refute_includes html, "message-header"
          refute_includes html, "message-footer"
          assert_includes html, "just the body"
        end

        def test_message_and_bubble_compose_the_ghost_padding_contract
          bubble = vc_test_controller.view_context.render(
            Bubble::Component.new(variant: :ghost).with_content("tool output")
          )
          html = render_inline(Component.new) do |message|
            message.with_header { "Tool" }
            bubble
          end.to_html

          assert_includes html, 'data-variant="ghost"', "Bubble emits the data-variant Message's :has() reads"
          # The :has() padding collapse itself lives in the theme rules the
          # header/footer names resolve to.
          assert_includes html, "cn-message-header"
        end
      end
    end
  end
end
