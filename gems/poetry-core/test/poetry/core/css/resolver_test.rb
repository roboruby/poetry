# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class ResolverTest < Minitest::Test
        def build_resolver
          Resolver.new
                  .base("inline-flex items-center")
                  .element(:icon, "size-4 shrink-0")
                  .variant(:color, red: "text-red-600", gray: "text-gray-600")
                  .variant(:size, sm: "text-sm", lg: "text-lg")
                  .compound({ color: :red, size: :lg }, "font-bold")
        end

        def test_renders_base_plus_matching_variants
          css = build_resolver.render(color: :red, size: :sm)

          assert_includes css, "inline-flex"
          assert_includes css, "text-red-600"
          assert_includes css, "text-sm"
          refute_includes css, "font-bold"
        end

        def test_compound_applies_only_when_all_criteria_match
          css = build_resolver.render(color: :red, size: :lg)

          assert_includes css, "font-bold"
        end

        def test_renders_named_element
          assert_equal "size-4 shrink-0", build_resolver.render(:icon)
        end

        def test_unknown_element_renders_empty
          assert_nil build_resolver.render(:nope)
        end

        def test_extra_classes_win_tailwind_conflicts
          css = build_resolver.render(color: :red, size: :sm, extra: "text-blue-500")

          assert_includes css, "text-blue-500"
          refute_includes css, "text-red-600" # same property: caller wins via the merger
        end

        def test_missing_criteria_keys_are_skipped_silently
          css = build_resolver.render(color: :gray)

          assert_includes css, "text-gray-600"
          refute_includes css, "text-sm"
        end

        def test_stores_no_defaults_by_design
          refute_respond_to Resolver.new, :defaults
        end

        def test_compound_requires_at_least_two_keys
          assert_raises(ArgumentError) { Resolver.new.compound({ color: :red }, "x") }
        end

        def test_all_classes_collects_the_whole_dictionary
          classes = build_resolver.all_classes

          assert_includes classes, "inline-flex"
          assert_includes classes, "size-4"
          assert_includes classes, "text-red-600"
          assert_includes classes, "font-bold"
          assert_equal classes.uniq, classes
        end

        def test_variant_options_exposes_the_declared_space
          assert_equal({ color: %i[red gray], size: %i[sm lg] }, build_resolver.variant_options)
        end

        def test_dup_isolates_the_copy_from_the_original
          original = build_resolver
          copy = original.dup
          copy.variant(:color, blue: "text-blue-600")
          copy.base("rounded")

          assert_nil original.variants[:color][:blue]
          refute_includes original.bases, "rounded"
          assert_equal "text-blue-600", copy.variants[:color][:blue]
        end
      end
    end
  end
end
