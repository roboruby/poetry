# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class BemReferenceTest < Minitest::Test
        def reference_css
          BemReference.new(Poetry::Core::X::Style).css
        end

        def test_header_carries_the_capsule_digest
          assert_includes reference_css, "capsule #{Poetry::Core::X::Style.capsule}"
        end

        def test_root_and_modifier_selectors_document_their_utilities
          css = reference_css

          assert_includes css, ".poetry-core-x { /* tailwind-equivalent: shrink-0 */ }"
          assert_includes css, ".poetry-core-x--size-small { /* tailwind-equivalent: size-3 */ }"
        end

        def test_compound_rules_chain_modifier_selectors
          assert_includes reference_css,
                          ".poetry-core-x--color-red.poetry-core-x--mode-dark " \
                          "{ /* tailwind-equivalent: stroke-red-400 group-hover:stroke-red-300 */ }"
        end

        def test_empty_utilities_are_documented_not_dropped
          assert_includes reference_css, ".poetry-core-x--mode-light { /* (no default styles) */ }"
        end

        def test_digest_is_deterministic_and_content_sensitive
          resolver_a = Resolver.new.base("p-4").variant(:color, red: "text-red-600")
          resolver_b = Resolver.new.base("p-4").variant(:color, red: "text-red-600")
          resolver_c = Resolver.new.base("p-4").variant(:color, red: "text-red-500")

          assert_equal resolver_a.digest, resolver_b.digest
          refute_equal resolver_a.digest, resolver_c.digest
        end
      end
    end
  end
end
