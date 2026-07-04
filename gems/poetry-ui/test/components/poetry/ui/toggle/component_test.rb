# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Toggle
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_toggle(text = "Italic", **)
          render_inline(Component.new(**)) { text }.to_html
        end

        def test_a_plain_button_with_the_pressed_vocabulary_and_no_bogus_role
          control = doc(render_toggle).css('button[data-slot="toggle"]').first

          assert_equal "toggle", control["data-component"]
          assert_equal "button", control["type"]
          assert_nil control["role"], "aria-pressed on a plain button IS the pattern - no role"
          assert_equal "false", control["aria-pressed"]
          refute control.key?("data-pressed"), "unpressed = attribute ABSENT (Base UI presence boolean)"
          # Vocabulary discipline: never the siblings' attributes.
          assert_nil control["aria-checked"]
          assert_nil control["aria-expanded"]
        end

        def test_the_pressed_micro_controller_is_wired
          control = doc(render_toggle).css('[data-slot="toggle"]').first

          assert_equal "poetry--core--pressed", control["data-controller"]
          assert_equal "click->poetry--core--pressed#toggle", control["data-action"]
        end

        def test_pressed_renders_the_on_projection
          control = doc(render_toggle(pressed: true)).css('[data-slot="toggle"]').first

          assert_equal "true", control["aria-pressed"]
          assert control.key?("data-pressed"), "pressed = bare data-pressed (Base UI presence boolean)"
        end

        def test_no_form_machinery_ever_renders
          html = render_toggle(pressed: true)

          assert_empty doc(html).css("input"), "Toggle is UI state, not form data - no hidden input, ever"
          refute Component.has_option_attribute?(:name), "no name: option exists (the boundary is unrepresentable)"
          refute Component.has_option_attribute?(:value)
        end

        def test_variant_and_size_classes_come_from_the_shared_dictionary
          control = doc(render_toggle(variant: :outline, size: :sm)).css('[data-slot="toggle"]').first

          assert_equal "outline", control["data-variant"]
          assert_equal "sm", control["data-size"]
          %w[border-input shadow-xs h-8 min-w-8 px-1.5].each { |token| assert_includes control["class"], token }
          # Outline's hover DOES use accent (source-exact) - the merger
          # collapses the base's muted hover, exactly as cn() does.
          assert_includes control["class"], "hover:bg-accent"
          refute_includes control["class"], "hover:bg-muted"

          base = doc(render_toggle).css('[data-slot="toggle"]').first

          # The base string on the default variant: MUTED hover (pressed
          # owns accent), the svg auto-size convention, the suite ring.
          %w[hover:bg-muted data-pressed:bg-accent data-pressed:text-accent-foreground
             focus-visible:ring-[3px] transition-[color,box-shadow]].each do |token|
            assert_includes base["class"], token
          end
          assert_includes base["class"], "[&_svg:not([class*='size-'])]:size-4"
        end

        def test_disabled_renders_native_disabled_plus_data_disabled
          control = doc(render_toggle(disabled: true)).css('[data-slot="toggle"]').first

          assert control.key?("disabled")
          assert control.key?("data-disabled"), "Radix parity styling hook (and the group roving filter)"
        end

        def test_icon_only_without_label_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new) { '<svg viewBox="0 0 24 24"></svg>'.html_safe }
          end

          assert_match(/state-invariant/, error.message)
          # An empty toggle is just as nameless.
          assert_raises(ArgumentError) { render_inline(Component.new) }
        end

        def test_icon_only_with_label_renders_the_aria_label
          html = render_inline(Component.new(label: "Bookmark")) do
            '<svg viewBox="0 0 24 24"></svg>'.html_safe
          end.to_html
          control = doc(html).css('[data-slot="toggle"]').first

          assert_equal "Bookmark", control["aria-label"]
        end

        def test_visible_text_is_the_accessible_name_and_needs_no_label
          control = doc(render_toggle("Italic")).css('[data-slot="toggle"]').first

          assert_equal "Italic", control.text.strip
          assert_nil control["aria-label"]
        end

        def test_caller_classes_merge_and_root_is_never_polymorphic
          control = doc(render_toggle("x", class: "h-7")).css('[data-slot="toggle"]').first

          assert_includes control["class"], "h-7"
          refute_includes control["class"], "h-9"
          refute Component.has_option_attribute?(:tag), "no tag: - aria-pressed on a link is a semantics lie"
        end
      end
    end
  end
end
