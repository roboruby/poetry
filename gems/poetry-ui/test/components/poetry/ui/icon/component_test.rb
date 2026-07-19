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

        def test_standalone_icon_carries_lucide_intrinsic_box
          html = render_inline(Component.new(name: :rocket)).to_html

          # Without width/height a standalone icon fills its container
          # (the 352px rocket, 2026-07-01 browser pass); [&_svg]:size-4
          # rules still win inside components.
          assert_includes html, 'width="24"'
          assert_includes html, 'height="24"'
        end

        def test_intrinsic_box_is_overridable
          html = render_inline(Component.new(name: :rocket, width: "48", height: "48")).to_html

          assert_includes html, 'width="48"'
          refute_includes html, 'width="24"'
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

        def test_the_invalid_message_names_the_closest_icon
          component = Component.new(name: :"alert-circle")

          refute_predicate component, :valid?
          assert_includes component.errors[:name].first, %(did you mean :"circle-alert"?)
        end

        # --- the missing-icon policy ---

        def test_an_unknown_icon_raises_in_local_envs
          # Rails.env "test" is local - dev/test keep the raise, so bad
          # literals die loudly where they're written.
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(name: :"definitely-not-an-icon"))
          end

          assert_includes error.message, "unknown icon"
        end

        def test_outside_local_envs_the_fallback_renders_and_the_hook_fires
          config = Poetry::Core::Config.current
          config.raise_on_missing_icon = false
          seen = nil
          config.on_missing_icon = ->(name:, library:, error:) { seen = [name, library, error.class] }

          html = render_inline(Component.new(name: :"definitely-not-an-icon")).to_html

          # The fallback's path data (render_inline normalizes self-closing
          # tags, so compare path geometry, not raw markup).
          assert_includes html, "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"
          assert_equal [:"definitely-not-an-icon", :lucide, ArgumentError], seen
        ensure
          config.raise_on_missing_icon = nil
          config.on_missing_icon = nil
        end

        def test_a_nil_fallback_reraises_the_original_error
          config = Poetry::Core::Config.current
          config.raise_on_missing_icon = false
          config.icon_fallback = nil

          error = assert_raises(ArgumentError) do
            render_inline(Component.new(name: :"definitely-not-an-icon"))
          end

          assert_includes error.message, "definitely-not-an-icon"
        ensure
          config.raise_on_missing_icon = nil
          config.icon_fallback = :"circle-question-mark"
        end

        def test_a_missing_fallback_reraises_the_original_error
          config = Poetry::Core::Config.current
          config.raise_on_missing_icon = false
          config.icon_fallback = :"also-not-an-icon"

          error = assert_raises(ArgumentError) do
            render_inline(Component.new(name: :"definitely-not-an-icon"))
          end

          assert_includes error.message, "definitely-not-an-icon"
        ensure
          config.raise_on_missing_icon = nil
          config.icon_fallback = :"circle-question-mark"
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
