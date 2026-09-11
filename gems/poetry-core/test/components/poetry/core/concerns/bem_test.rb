# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      # The BEM token IR + css_mode emission.
      class BemTest < ViewComponent::TestCase
        # A minimal styled component exercising symbol AND boolean modifiers.
        module Chip
          class Component < Poetry::Core::Component
            style :color, default: :gray, variants: %i[gray red]
            style :outlined, variants: :boolean, default: false

            def call
              content_tag(:span, "chip", class: css)
            end
          end

          class Style < Poetry::Core::Style
            base "inline-flex rounded"
            element :icon, "size-3"
            variant :color, gray: "bg-muted text-muted-foreground", red: "bg-destructive/15 text-destructive"
            variant :outlined, { true => "border border-border", false => "" }
          end
        end

        def teardown
          Poetry::Core::Config.current.css_mode = :tailwind
        end

        def test_bem_block_derives_from_component_path
          assert_equal "poetry-core-box", Poetry::Core::Box::Component.new.bem_block
        end

        def test_bem_emits_block_plus_value_modifiers
          chip = Chip::Component.new(color: :red)
          bem = chip.bem

          assert_includes bem, chip.bem_block
          assert_includes bem, "#{chip.bem_block}--color-red"
          # A defaulted VALUE variant still names its modifier (booleans
          # are presence modifiers - false emits nothing).
          assert_includes Chip::Component.new(outlined: true).bem, "#{chip.bem_block}--color-gray"
        end

        def test_boolean_styles_are_presence_modifiers
          chip = Chip::Component.new(outlined: true)

          assert_includes chip.bem, "--outlined"
          refute_includes Chip::Component.new(outlined: false).bem, "--outlined"
        end

        def test_bem_element
          chip = Chip::Component.new

          assert_equal "#{chip.bem_block}__icon", chip.bem(:icon)
        end

        # A kit declares its mode once on a base; subclasses inherit it.
        module Kit
          class Base < Poetry::Core::Component
            css_mode :bem
          end

          # The sidecar convention: Tag::Component resolves Tag::Style.
          module Tag
            class Component < Base
              style :tone, default: :sky, variants: %i[sky rose]

              def call
                content_tag(:span, "tag", class: css)
              end
            end

            class Style < Poetry::Core::Style
              base "inline-flex"
              variant :tone, sky: "bg-sky-100", rose: "bg-rose-100"
            end
          end
        end

        def test_css_mode_declared_on_a_base_is_inherited_and_beats_the_global
          assert_equal :bem, Kit::Base.css_mode
          assert_equal :bem, Kit::Tag::Component.css_mode
          assert_equal :tailwind, Chip::Component.css_mode, "an undeclared kit follows the global"
          css = Kit::Tag::Component.new(tone: :rose).css

          assert_includes css, "poetry-core-concerns-bem_test-kit-tag--tone-rose"
          refute_includes css, "bg-rose-100"
        end

        def test_a_namespace_pin_beats_the_global_and_a_declaration_beats_the_pin
          Poetry::Core::CSS::Modes.pin("Poetry::Core::Concerns::BemTest", :bem)
          Poetry::Core::Config.current.css_mode = :tailwind

          assert_equal :bem, Chip::Component.css_mode, "pinned namespace, global ignored"
          assert_includes Chip::Component.new(color: :red).css, "--color-red"
          Poetry::Core::CSS::Modes.pin("Poetry::Core::Concerns::BemTest::Kit", :tailwind)

          assert_equal :bem, Kit::Tag::Component.css_mode, "the class declaration wins over its namespace pin"
        ensure
          Poetry::Core::CSS::Modes.unpin("Poetry::Core::Concerns::BemTest")
          Poetry::Core::CSS::Modes.unpin("Poetry::Core::Concerns::BemTest::Kit")
        end

        def test_the_longest_matching_namespace_pin_wins
          Poetry::Core::CSS::Modes.pin("Poetry::Core", :bem)
          Poetry::Core::CSS::Modes.pin("Poetry::Core::Concerns::BemTest::Chip", :tailwind)

          assert_equal :tailwind, Poetry::Core::CSS::Modes.for(Chip::Component)
          assert_equal :bem, Poetry::Core::CSS::Modes.for(Poetry::Core::Box::Component)
          assert_nil Poetry::Core::CSS::Modes.for(Class.new(Poetry::Core::Component) { def self.name = "Other::Thing" })
        ensure
          Poetry::Core::CSS::Modes.unpin("Poetry::Core")
          Poetry::Core::CSS::Modes.unpin("Poetry::Core::Concerns::BemTest::Chip")
        end

        def test_the_merger_follows_the_kit_s_mode
          assert_instance_of Poetry::Core::CSS::BemMerger, Kit::Tag::Component.new.classname_merger
          assert_same Poetry::Core::Config.current.classname_merger, Chip::Component.new.classname_merger,
                      "a kit on the global :tailwind mode merges with the configured merger"
          # A BEM kit dedupes tokens and never resolves utility conflicts;
          # a Tailwind kit resolves them. Both through the root attributes.
          bem_root = Kit::Tag::Component.new(class: "acme acme--x acme").html_attributes
          tailwind_root = Chip::Component.new(class: "acme acme--x acme").html_attributes

          assert bem_root.merge_classes("p-4 p-2")["class"].end_with?(" acme acme--x p-4 p-2"),
                 "BEM: dedupe, no conflicts"
          assert tailwind_root.merge_classes("p-4 p-2")["class"].end_with?(" acme acme--x acme p-2"),
                 "Tailwind: conflicts"
        end

        def test_the_global_merger_is_honoured_when_it_matches_the_mode_and_replaced_when_it_does_not
          bem = Poetry::Core::CSS::BemMerger.new
          Poetry::Core::Config.current.classname_merger = bem

          assert_same bem, Poetry::Core::CSS::Modes.merger_for(:bem), "a host's BEM merger serves its BEM kit"
          assert_instance_of Poetry::Core::CSS::TailwindMerger, Poetry::Core::CSS::Modes.merger_for(:tailwind),
                             "a Tailwind kit falls back to the stock Tailwind merger"
          assert_same Poetry::Core::CSS::Modes.merger_for(:tailwind), Poetry::Core::CSS::Modes.merger_for(:tailwind),
                      "stock mergers are built once"
          tailwind = Poetry::Core::CSS::TailwindMerger.new
          Poetry::Core::Config.current.classname_merger = tailwind

          assert_same tailwind, Poetry::Core::CSS::Modes.merger_for(:tailwind), "a customised Tailwind merger is kept"
          assert_instance_of Poetry::Core::CSS::BemMerger, Poetry::Core::CSS::Modes.merger_for(:bem)
        ensure
          Poetry::Core::Config.current.classname_merger = Poetry::Core::CSS::TailwindMerger.new
        end

        def test_an_attributes_copy_keeps_the_assigned_merger
          attrs = Poetry::Core::HTML::Attributes.new(class: "acme acme")
          attrs.classname_merger = Poetry::Core::CSS::BemMerger.new

          assert_equal "acme x", attrs.dup.merge_classes!("x")["class"]
          assert_equal "acme x", attrs.deep_dup.merge_classes!("x")["class"]
          assert_equal "acme x", attrs.merge(class: "x")["class"]
          assert_equal "acme x", attrs.merge_classes("x")["class"]
          plain = Poetry::Core::HTML::Attributes.new(class: "acme acme")

          assert_equal "acme acme x", plain.merge_classes("x")["class"],
                       "no assigned merger: the global keeps duplicates"
        end

        def test_a_per_call_mode_wins_over_a_declaration
          assert_includes Kit::Tag::Component.new(tone: :rose).css(css_mode: :tailwind), "bg-rose-100"
        end

        def test_an_unknown_declared_mode_raises
          assert_raises(Poetry::Core::Error) { Class.new(Poetry::Core::Component) { css_mode :sass } }
          assert_raises(Poetry::Core::Error) { Poetry::Core::CSS::Modes.pin("X", :sass) }
        end

        def test_css_mode_tailwind_is_the_default
          assert_equal :tailwind, Poetry::Core::Config.current.css_mode
          assert_includes Chip::Component.new.css, "bg-muted"
        end

        def test_css_mode_bem_per_call_override
          css = Chip::Component.new(color: :red).css(css_mode: :bem)

          assert_includes css, "--color-red"
          refute_includes css, "bg-destructive/15"
        end

        def test_css_mode_bem_appends_caller_classes_verbatim
          css = Chip::Component.new.css(css_mode: :bem, class: "my-custom")

          assert css.end_with?("my-custom")
        end

        def test_unknown_css_mode_raises
          assert_raises(Poetry::Core::Error) { Chip::Component.new.css(css_mode: :both) }
        end

        # The dual-mode contract: the same component renders under BOTH
        # modes via the global config switch.
        def test_component_renders_in_both_modes
          Poetry::Core::Config.current.css_mode = :tailwind
          tailwind_html = render_inline(Chip::Component.new(color: :red)).to_html

          assert_includes tailwind_html, "text-destructive"
          refute_includes tailwind_html, "--color-red"

          Poetry::Core::Config.current.css_mode = :bem
          bem_html = render_inline(Chip::Component.new(color: :red)).to_html

          assert_includes bem_html, "--color-red"
          refute_includes bem_html, "text-destructive"
        end
      end
    end
  end
end
