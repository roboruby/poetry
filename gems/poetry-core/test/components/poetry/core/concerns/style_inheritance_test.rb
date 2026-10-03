# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      # A subclass without a sidecar Style of its own renders through its
      # parent's dictionary; one with a sidecar takes that over.
      class StyleInheritanceTest < ViewComponent::TestCase
        module Pill
          class Component < Poetry::Core::Component
            style :tone, default: :neutral, variants: %i[neutral loud]

            def call
              content_tag(:span, content, class: css)
            end
          end

          class Style < Poetry::Core::Style
            base "pill"
            variant :tone, neutral: "pill-neutral", loud: "pill-loud"
          end
        end

        # The bare subclass the queue describes: no Style beside it.
        class LoudPill < Pill::Component
          def initialize(**)
            super(tone: :loud, **)
          end
        end

        # Two levels down, still bare.
        class LouderPill < LoudPill
        end

        # A sidecar of its own wins over the inherited one.
        module Tag
          class Component < Pill::Component
          end

          class Style < Pill::Style
            variant :tone, { shouted: "tag-shouted" }
          end
        end

        # Built directly on the base with nothing beside it: no dictionary.
        class Plain < Poetry::Core::Component
          def call = "plain"
        end

        def test_a_bare_subclass_inherits_its_parent_dictionary
          assert_same Pill::Style, LoudPill.style_class
          assert_same Pill::Style, LouderPill.style_class
        end

        def test_a_bare_subclass_renders_the_parent_classes
          parent = render_inline(Pill::Component.new(tone: :loud)) { "x" }.css("span").first["class"]
          child = render_inline(LoudPill.new) { "x" }.css("span").first["class"]
          grandchild = render_inline(LouderPill.new) { "x" }.css("span").first["class"]

          assert_equal "pill pill-loud", parent
          assert_equal parent, child
          assert_equal parent, grandchild
        end

        def test_a_sidecar_of_its_own_takes_over
          assert_same Tag::Style, Tag::Component.style_class
          assert_includes Tag::Component.style_class.variant_options[:tone], :shouted
          refute_includes Pill::Style.variant_options[:tone], :shouted
        end

        def test_a_component_on_the_base_with_no_sidecar_has_no_dictionary
          assert_nil Plain.style_class
          assert_nil Plain.new.css
        end
      end
    end
  end
end
