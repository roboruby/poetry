# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-three text effects render the finished text for readers and
    # for the eye, and animate only an aria-hidden copy.
    class TextEffectsTest < ViewComponent::TestCase
      def test_typewriter_renders_the_whole_line_twice_with_a_caret
        render_inline(Typewriter::Component.new("Hello there", speed: 30))
        root = page.find("[data-slot=typewriter]")

        assert_selector ".sr-only", text: "Hello there", visible: :all
        display = page.find("[data-slot=typewriter-display]", visible: :all)

        assert_equal "Hello there", display.text
        assert_equal "true", display["aria-hidden"]
        assert root.matches_css?("[data-cursor]")
        assert_equal "30", root["data-poetry--motion--typewriter-speed-value"]
        assert_raises(ArgumentError) { render_inline(Typewriter::Component.new("x", speed: 1)) }
      end

      def test_scramble_renders_its_text_and_a_duration_in_milliseconds
        render_inline(Scramble::Component.new("ACCESS", duration: :fast))

        assert_equal "400", page.find("[data-slot=scramble]")["data-poetry--motion--scramble-duration-value"]
        assert_equal "ACCESS", page.find("[data-slot=scramble-display]", visible: :all).text
      end

      def test_word_rotate_stacks_the_words_with_the_first_active
        render_inline(WordRotate::Component.new(words: %w[faster safer], rounds: 2))
        root = page.find("[data-slot=word-rotate]")

        assert_selector ".sr-only", text: "faster", visible: :all
        words = page.all("[data-slot=word-rotate-word]", visible: :all)

        assert_equal %w[faster safer], words.map(&:text)
        assert words.first.matches_css?("[data-active]", visible: :all)
        refute words.last.matches_css?("[data-active]", visible: :all)
        assert_equal "2", root["data-poetry--motion--word-rotate-rounds-value"]
        assert_raises(ArgumentError) { render_inline(WordRotate::Component.new(words: %w[alone])) }
      end

      def test_without_motion_nothing_is_wired
        render_inline(Typewriter::Component.new("Still", animate: false))

        assert_nil page.find("[data-slot=typewriter]")["data-controller"]
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_typewriter("Hi"), "data-slot=\"typewriter\""
        assert_includes view.poetry_scramble("Hi"), "data-slot=\"scramble\""
        assert_includes view.poetry_word_rotate(words: %w[a b]), "data-slot=\"word-rotate\""
      end
    end
  end
end
