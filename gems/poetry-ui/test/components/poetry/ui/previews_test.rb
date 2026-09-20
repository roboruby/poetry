# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The M4 preview bar: every preview example renders (previews double as
    # test fixtures - one corpus for Lookbook, docs, and the agent loop).
    class PreviewsTest < ViewComponent::TestCase
      def test_every_button_preview_example_renders
        Button::Preview.examples.each do |example|
          render_preview(example, from: Button::Preview)

          assert_includes rendered_content, 'data-component="button"', "preview #{example} must render a Button"
        end
      end

      def test_every_icon_preview_example_renders
        Icon::Preview.examples.each do |example|
          render_preview(example, from: Icon::Preview)

          assert_includes rendered_content, 'data-component="icon"', "preview #{example} must render an Icon"
        end
      end

      def test_previews_cover_the_full_variant_axis
        # The variant group must cover every declared variant (the preview
        # matrix keeps pace with the contract).
        Button::Component::VARIANTS.each do |variant|
          assert_includes Button::Preview.examples, variant.to_s,
                          "missing preview for variant #{variant}"
        end
      end
    end
  end
end
