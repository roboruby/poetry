# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class ThemeCoverageTest < Minitest::Test
        THEME = <<~CSS
          .cn-widget {
            @apply rounded-md text-sm;
          }

          .cn-widget-variant-primary {
            @apply bg-primary;
          }

          .cn-widget-variant-primary.cn-widget-size-sm {
            @apply px-1;
          }

          .cn-dead-rule {
            @apply underline;
          }

          .cn-font-heading {
            @apply font-medium;
          }
        CSS

        def coverage(style_classes:, allowlist: [])
          ThemeCoverage.new(theme_css: THEME, style_classes: style_classes, allowlist: allowlist)
        end

        # Anonymous Style subclasses stay out of the rake gates
        # (descendants.select(&:name) filters them) - safe as fixtures.
        def converted_style
          Class.new(Poetry::Core::Style) do
            base "cn-widget inline-flex"
            variant :variant, primary: "cn-widget-variant-primary"
            variant :size, sm: "cn-widget-size-sm"
          end
        end

        def test_clean_coverage_with_allowlisted_utility_and_one_dead_rule
          cov = coverage(style_classes: [converted_style], allowlist: ["cn-font-heading"])

          assert_empty cov.missing
          assert_equal ["cn-dead-rule"], cov.orphans
          refute_predicate cov, :ok?
        end

        def test_missing_names_the_unthemed_dictionary_entry
          style = Class.new(Poetry::Core::Style) do
            base "cn-widget"
            variant :variant, ghost: "cn-widget-variant-ghost"
          end
          cov = coverage(style_classes: [style], allowlist: %w[cn-font-heading cn-dead-rule])

          assert_equal ["cn-widget-variant-ghost"], cov.missing
        end

        def test_combined_compound_selectors_contribute_every_token
          assert_includes coverage(style_classes: []).theme_names, "cn-widget-size-sm"
        end

        def test_unconverted_utility_dictionaries_are_invisible
          legacy = Class.new(Poetry::Core::Style) do
            base "shrink-0"
            variant :color, red: "stroke-red-600/50"
          end

          assert_empty coverage(style_classes: [legacy]).missing
        end

        def test_apply_bodies_are_never_read_as_selectors
          refute_includes coverage(style_classes: []).theme_names, "cn-bg-primary"
          assert_equal 5, coverage(style_classes: []).theme_names.size
        end
      end
    end
  end
end
