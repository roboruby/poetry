# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class VerifierTest < Minitest::Test
        FIXTURE = File.read(File.expand_path("../../../fixtures/tailwind_compiled.css", __dir__))

        def setup
          @verifier = Verifier.new(compiled_css: FIXTURE)
        end

        def test_parses_escaped_tailwind_selectors_into_authored_names
          known = @verifier.known

          assert_includes known, "p-4"
          assert_includes known, "size-3.5"
          assert_includes known, "stroke-red-600/50"
          assert_includes known, "group-hover:stroke-red-600/75"
          assert_includes known, "data-[state=open]:block"
          assert_includes known, "sm:flex", "rules nested in @media must be found"
        end

        def test_declaration_values_and_dimensions_are_not_classes
          known = @verifier.known

          refute_includes known, "25rem"
          refute_includes known, "5rem"
          refute_includes known, "875rem"
        end

        def test_known_classes_pass
          assert_empty @verifier.unknown(%w[p-4 sm:flex stroke-red-600/50])
        end

        # The M2 DoD: the Verifier catches a hallucinated class.
        def test_catches_a_hallucinated_class
          unknown = @verifier.unknown(%w[p-4 strke-red-600/50])

          assert_equal 1, unknown.size
          assert_equal "strke-red-600/50", unknown.first.class_name
          assert_equal "stroke-red-600/50", unknown.first.suggestion, "the near-miss should be suggested"
        end

        def test_far_off_hallucinations_get_no_suggestion
          unknown = @verifier.unknown(%w[btn-primary-lg-wat])

          assert_equal 1, unknown.size
          assert_nil unknown.first.suggestion
        end

        def test_verify_style_flags_dictionary_classes_missing_from_the_build
          style = Class.new(Poetry::Core::Style) do
            base "inline-flex rounded"
            variant :color, red: "text-red-600", blue: "text-blue-600" # blue is not in the fixture build
          end

          unknown = @verifier.verify_style(style).map(&:class_name)

          assert_equal ["text-blue-600"], unknown
        end
      end
    end
  end
end
