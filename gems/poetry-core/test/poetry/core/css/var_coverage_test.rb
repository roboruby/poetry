# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class VarCoverageTest < Minitest::Test
        def coverage(css, **)
          VarCoverage.new(compiled_css: css, **)
        end

        def test_declared_reads_resolve
          css = ":root { --primary: oklch(0.2 0 0); } .a { color: var(--primary); }"

          assert_predicate coverage(css), :ok?
        end

        def test_undeclared_read_is_dead
          css = ".a { color: var(--primary); }"

          assert_equal ["--primary"], coverage(css).dead_reads
        end

        def test_read_with_fallback_still_requires_a_definition
          css = ".a { transform-origin: var(--radix-popover-transform-origin, center); }"

          assert_equal ["--radix-popover-transform-origin"], coverage(css).dead_reads
        end

        def test_property_registration_counts_as_definition
          css = "@property --tw-shadow { syntax: \"*\"; } .a { box-shadow: var(--tw-shadow); }"

          assert_predicate coverage(css), :ok?
        end

        def test_extra_definitions_cover_runtime_assignments
          css = ".a { width: var(--anchor-width); }"

          assert_equal ["--anchor-width"], coverage(css).dead_reads
          assert_predicate coverage(css, extra_definitions: ["--anchor-width"]), :ok?
        end

        def test_definition_prefixes_cover_dynamic_runtime_names
          css = ".a { translate: var(--drawer-swipe-movement-x); }"

          assert_predicate coverage(css, definition_prefixes: ["--drawer-swipe-movement-"]), :ok?
          assert_equal ["--drawer-swipe-movement-x"], coverage(css).dead_reads
        end

        def test_extra_reads_come_from_inline_styles
          css = ":root { --sidebar-width: 16rem; }"
          with_read = coverage(css, extra_reads: ["--sidebar-width", "--missing"])

          assert_equal ["--missing"], with_read.dead_reads
        end

        def test_stimulus_event_tokens_are_not_declarations
          css = "/* poetry--core--calendar:change */ .a { color: var(--core--calendar); }"

          assert_equal ["--core--calendar"], coverage(css).dead_reads
        end

        def test_comments_are_stripped_before_scanning
          css = "/* var(--ghost) and --ghost: red; */ :root { --real: 1; } .a { top: var(--real); }"
          instance = coverage(css)

          assert_predicate instance, :ok?
          refute_includes instance.definitions, "--ghost"
        end

        def test_declaration_inside_rule_body_defines
          css = ".cn-item { --indent: 1rem; padding-left: var(--indent); }"

          assert_predicate coverage(css), :ok?
        end
      end
    end
  end
end
