# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Toaster
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_toaster(**, &)
          render_inline(Component.new(**), &).to_html
        end

        def test_the_viewport_is_a_labeled_permanent_region
          html = render_toaster
          region = doc(html).css('ol[data-slot="toaster"]').first

          assert region, "the viewport is an <ol> (list semantics)"
          assert_equal "toaster", region["data-component"]
          # The Turbo Stream append target + flash-after-redirect survival.
          assert_equal "poetry-toaster", region["id"]
          assert region.key?("data-turbo-permanent")
          assert_equal "region", region["role"]
          assert_equal "Notifications (F8)", region["aria-label"], "the label NAMES the hotkey (i18n)"
          assert_equal "-1", region["tabindex"]
        end

        def test_controller_values_and_the_position_stamp
          region = doc(render_toaster).css('[data-slot="toaster"]').first

          assert_equal "poetry--core--toaster", region["data-controller"]
          assert_equal "F8", region["data-poetry--core--toaster-hotkey-value"]
          assert_equal "3", region["data-poetry--core--toaster-limit-value"]
          assert_equal "bottom-right", region["data-poetry--core--toaster-position-value"]
          # The items' slide-direction selectors key on this stamp.
          assert_equal "bottom-right", region["data-position"]
          assert_includes region["class"], "bottom-0"
          assert_includes region["class"], "right-0"
          assert_includes region["class"], "pointer-events-none"
          assert_includes region["class"], "group/toaster"
        end

        def test_every_position_lands_its_corner_classes
          { "top-left": %w[top-0 left-0], "top-center": %w[top-0 -translate-x-1/2],
            "bottom-center": %w[bottom-0 -translate-x-1/2], "bottom-left": %w[bottom-0 left-0] }
            .each do |position, classes|
            region = doc(render_toaster(position: position)).css('[data-slot="toaster"]').first

            assert_equal position.to_s, region["data-position"]
            classes.each { |css_class| assert_includes region["class"], css_class }
          end
        end

        def test_hotkey_and_limit_are_configurable
          region = doc(render_toaster(hotkey: "F9", limit: 5)).css('[data-slot="toaster"]').first

          assert_equal "F9", region["data-poetry--core--toaster-hotkey-value"]
          assert_equal "Notifications (F9)", region["aria-label"]
          assert_equal "5", region["data-poetry--core--toaster-limit-value"]
        end

        def test_server_rendered_toasts_stack_inside_the_region
          html = render_toaster do
            render_inline(Toast::Component.new(variant: :success).tap { |t| t.with_title { "Saved" } }).to_html
                                                                                                       .html_safe
          end

          assert_predicate doc(html).css('[data-slot="toaster"] [data-slot="toast"]'), :any?,
                           "the no-JS baseline: server toasts render as a static stacked list"
        end
      end
    end
  end
end
