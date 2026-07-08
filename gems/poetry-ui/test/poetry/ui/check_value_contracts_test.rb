# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The value-contract regression corpus: the 31 committed W2
    # benchmark generated poetry arms plus the 31 frozen handwritten arms,
    # linted with the full production catalog (live registry + helper
    # introspection + the real lucide names). The three W2 render-crashers
    # must now fail poetry check statically; every template that rendered
    # must stay error-free - recall on real crashes bought with zero false
    # positives.
    class CheckValueContractsTest < Minitest::Test
      CRASHERS = %w[alert empty_state filter_toolbar].freeze
      GENERATED = "eval/results/2026-07-07/generated/*/poetry.html.erb"
      FROZEN = "eval/arms/*/poetry.html.erb"

      def catalog
        @catalog ||= Poetry::Core::Check::Catalog.from_registry(
          Poetry::Ui.root,
          helpers: Poetry::Ui::ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/),
          icon_names: Poetry::Core::Icons.set.names
        )
      end

      # task name => error findings, for every template with any.
      def error_templates(glob)
        Dir.glob(Poetry::Ui.root.join(glob).to_s).filter_map do |path|
          errors = Poetry::Core::Check.lint(File.read(path), catalog: catalog)
                                      .select { |finding| finding.severity == :error }
          [File.basename(File.dirname(path)), errors] if errors.any?
        end.to_h
      end

      def test_the_generated_corpus_errors_on_exactly_the_three_crash_classes
        failures = error_templates(GENERATED)

        assert_equal CRASHERS, failures.keys.sort,
                     "check must flag the three W2 render-crashers and nothing else, got: " \
                     "#{failures.transform_values { |findings| findings.map(&:rule) }}"
        assert(failures["alert"].any? { |finding| finding.rule == "missing-option" },
               "the typed-slot block form (with_icon do) must read as a missing required prop")
        assert(failures["empty_state"].any? { |finding| finding.rule == "unknown-icon" },
               ":folder_plus must read as a bad icon name")
        assert(failures["filter_toolbar"].any? { |finding| finding.rule == "unknown-variant" },
               "align: :leading must read as an enum violation")
      end

      def test_the_frozen_arms_stay_error_free
        assert_empty error_templates(FROZEN),
                     "maintainer-written arms render today - new rules must not flag them"
      end
    end
  end
end
