# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Bubble
      class ComponentTest < ViewComponent::TestCase
        def test_renders_the_contract_surface
          html = render_inline(Component.new) { "Hello" }.to_html

          assert_includes html, 'data-component="bubble"'
          assert_includes html, 'data-slot="bubble"'
          assert_includes html, 'data-variant="default"'
          assert_includes html, 'data-align="start"'
          assert_match(%r{<div[^>]*data-slot="bubble-content"[^>]*>Hello</div>}, html)
        end

        def test_every_variant_renders_with_its_data_marker
          Component::VARIANTS.each do |variant|
            html = render_inline(Component.new(variant: variant)) { "x" }.to_html

            assert_includes html, %(data-variant="#{variant}"), variant.to_s
          end
        end

        def test_variant_classes_style_the_content_child_from_the_root
          html = render_inline(Component.new) { "x" }.to_html

          assert_includes html, "*:data-[slot=bubble-content]:bg-primary"
        end

        def test_quick_reply_content_is_a_real_button_or_link
          button = render_inline(Component.new(variant: :outline, tag: :button)) { "Yes" }.to_html
          link = render_inline(Component.new(tag: :a, href: "/x")) { "View" }.to_html

          assert_match(%r{<button[^>]*>Yes</button>}, button)
          assert_match(/<button[^>]*type="button"/, button)
          assert_match(/<button[^>]*data-slot="bubble-content"/, button)
          assert_match(%r{<a[^>]*href="/x"[^>]*>View</a>}, link)
        end

        def test_reactions_require_a_label_and_stamp_placement_data
          html = render_inline(Component.new) do |bubble|
            bubble.with_reactions(label: "Reactions", side: :top, align: :start) { "👍" }
            bubble.with_content("x")
          end.to_html

          assert_match(/<div[^>]*data-slot="bubble-reactions"[^>]*>/, html)
          assert_includes html, 'data-side="top"'
          assert_includes html, 'data-align="start"'
          assert_includes html, 'role="group"'
          assert_includes html, 'aria-label="Reactions"'
          assert_raises(ArgumentError) do
            render_inline(Component.new) do |bubble|
              bubble.with_reactions { "x" }
              bubble.with_content("y")
            end
          end
        end

        def test_align_end_and_ghost_carry_their_layout_hooks
          html = render_inline(Component.new(align: :end, variant: :ghost)) { "x" }.to_html

          assert_includes html, "data-[align=end]:self-end"
          assert_includes html, "data-[variant=ghost]:max-w-full"
        end
      end
    end
  end
end
