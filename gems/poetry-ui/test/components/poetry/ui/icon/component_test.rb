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
          refute_predicate Component.new(name: :"definitely-not-an-icon"), :valid?
        end

        def test_the_full_lucide_set_is_available
          # M5: the real vendored set, not the M3.5 three-icon stub.
          html = render_inline(Component.new(name: :calendar)).to_html

          assert_includes html, "<path"
        end

        # Swap the icon set via config.
        def test_swapping_the_icon_set_via_config
          fake = Class.new do
            def include?(_name) = true
            def fetch(_name) = '<circle cx="12" cy="12" r="10"/>'
            def names = [:dot]
          end.new
          Poetry::Core::Icons.register(:fake_set, fake)
          Poetry::Core::Config.current.icon_library = :fake_set

          html = render_inline(Component.new(name: :anything)).to_html

          assert_includes html, "<circle"
        ensure
          Poetry::Core::Config.current.icon_library = :lucide
        end

        def test_per_render_library_override
          html = render_inline(Component.new(name: :plus, library: :lucide)).to_html

          assert_includes html, 'data-component="icon"'
        end
      end
    end
  end
end
