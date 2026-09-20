# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Marker
      class ComponentTest < ViewComponent::TestCase
        def test_renders_announced_content_never_a_separator_role
          html = render_inline(Component.new(variant: :separator)) { "Yesterday" }.to_html

          assert_includes html, 'data-component="marker"'
          assert_includes html, 'data-variant="separator"'
          assert_match(%r{<span[^>]*data-slot="marker-content"[^>]*>Yesterday</span>}, html)
          refute_includes html, 'role="separator"', "divider lines are pseudo-elements; the label is the information"
        end

        def test_every_variant_renders
          Component::VARIANTS.each do |variant|
            html = render_inline(Component.new(variant: variant)) { "x" }.to_html

            assert_includes html, %(data-variant="#{variant}")
          end
        end

        def test_announce_status_is_a_live_region
          html = render_inline(Component.new(announce: :status)) { "Searching…" }.to_html

          assert_includes html, 'role="status"'
          refute_includes render_inline(Component.new) { "static" }.to_html, 'role="status"'
        end

        def test_icon_slot_is_typed_and_decorative
          html = render_inline(Component.new) do |marker|
            marker.with_icon(name: :sparkles)
            marker.with_content("Generating")
          end.to_html

          assert_match(/<span[^>]*data-slot="marker-icon"[^>]*aria-hidden="true"/, html)
          assert_includes html, "<svg"
        end
      end
    end
  end
end
