# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Icon
      class ComponentTest < ViewComponent::TestCase
        def test_renders_the_vendored_path_with_lucide_attributes
          html = render_inline(Component.new(name: :plus)).to_html

          assert_includes html, "<svg"
          assert_includes html, 'viewBox="0 0 24 24"'
          assert_includes html, 'stroke="currentColor"'
          assert_includes html, '<path d="M5 12h14">'
          assert_includes html, 'data-component="icon"'
        end

        def test_decorative_by_default
          html = render_inline(Component.new(name: :trash)).to_html

          assert_includes html, 'aria-hidden="true"'
          assert_includes html, 'focusable="false"'
          refute_includes html, "role="
        end

        def test_labeled_icon_is_standalone_with_an_accessible_name
          html = render_inline(Component.new(name: :trash, label: "Delete")).to_html

          assert_includes html, 'role="img"'
          assert_includes html, 'aria-label="Delete"'
          refute_includes html, "aria-hidden"
        end

        def test_unknown_icon_name_is_invalid
          refute_predicate Component.new(name: :sparkles), :valid?
        end
      end
    end
  end
end
