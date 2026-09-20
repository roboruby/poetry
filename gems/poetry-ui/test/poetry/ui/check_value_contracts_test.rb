# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The value-contract regression corpus: the 31 committed benchmark-
    # generated poetry arms plus the 31 frozen handwritten arms,
    # linted with the full production catalog (live registry + helper
    # introspection + the real lucide names). The three original render-crashers
    # must now fail poetry check statically; every template that rendered
    # must stay error-free - recall on real crashes bought with zero false
    # positives.
    class CheckValueContractsTest < Minitest::Test
      CRASHERS = %w[alert empty_state filter_toolbar].freeze
      GENERATED = "eval/results/2026-07-07/generated/*/poetry.html.erb"
      REMEDIATED = "eval/results/2026-07-08/generated/*/poetry.html.erb"
      BLOCKS_GATE = "eval/results/2026-07-09/generated/*/poetry.html.erb"
      REBASELINE = "eval/results/2026-07-09-rebaseline/generated/*/poetry.html.erb"
      DESIGNFIRE = "eval/results/2026-07-10-designfire/generated/*/poetry.html.erb"
      BLOCKPATH = "eval/results/2026-07-11-blockpath/generated/*/poetry.html.erb"
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
                     "check must flag the three original render-crashers and nothing else, got: " \
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

      # The composition-contract corpus: the remediation re-run's two
      # render-crashers fail statically (yield-less wrapper misuse, slot
      # setter arity), the three value-contract fixes stay clean.
      def test_the_remediated_corpus_errors_on_exactly_the_two_composition_crashers
        failures = error_templates(REMEDIATED)

        assert_equal %w[app_shell menu], failures.keys.sort,
                     "got: #{failures.transform_values { |findings| findings.map(&:rule).uniq }}"
        assert(failures["app_shell"].any? { |finding| finding.rule == "yieldless-block" },
               "a block param on a yield-less wrapper must read as the app_shell crash")
        assert(failures["menu"].any? { |finding| finding.rule == "slot-arity" },
               "the type-as-argument convention must read as the menu crash")
        assert(failures["menu"].any? { |finding| finding.suggestion == "with_separator" },
               "with_item(:separator) must suggest the sibling setter")
      end

      # The blocks-gate corpus (2026-07-09): the run's two render-crashers
      # fail statically - data_table guessed lucide's renamed :filter (the
      # icon-membership tier, catchable at generation time had the agent
      # run check), and site_nav passed positional text to kwargs-only
      # helpers, the class the helper-arity rule was built from. All FIVE
      # of site_nav's arity misuses surface, not just the first crash.
      # The re-baseline corpus: ALL FIVE render-
      # crashers now fail statically. The two sequencing failures were
      # already caught (chat_transcript's parse errors, filter_toolbar's
      # enum); the three TIER GAPS are the new rules - menu's block param on
      # a yieldless setter, floating's blockless Avatar (requires_content),
      # artwork_carousel's unknown keyword on a closed setter signature.
      # Every template that rendered stays error-free (the 26-arm FP guard).
      def test_the_rebaseline_corpus_errors_on_exactly_the_five_crashers
        failures = error_templates(REBASELINE)

        assert_equal %w[artwork_carousel chat_transcript filter_toolbar floating menu],
                     failures.keys.sort,
                     "got: #{failures.transform_values { |findings| findings.map(&:rule).uniq }}"
        assert(failures["menu"].any? { |finding| finding.rule == "yieldless-block" },
               "a block param on a block-consuming slot setter must read as the menu crash")
        assert(failures["floating"].any? { |finding| finding.rule == "missing-content-block" },
               "a blockless call on a requires_content component must read as the floating crash")
        keyword = failures["artwork_carousel"].find { |finding| finding.rule == "slot-keyword" }

        refute_nil keyword, "class: against a closed setter signature must read as the carousel crash"
        assert_equal "classes", keyword.suggestion, "the near-miss keyword must suggest the real one"
        assert(failures["menu"].any? { |finding| finding.rule == "missing-slot" },
               "the missing-slot tier exposes the arm's SECOND defect: both menubar menus also omit with_trigger " \
               "(the yieldless crash got there first at render)")
      end

      # The design-fire corpus: menu's required-SLOT omission (the
      # missing-slot tier), command_palette's accessible name and toast's
      # invisible Button (the any-of tier) all fail
      # statically now - four of the run's five crashers; pagination's
      # invented host route helper stays outside any static surface, by
      # nature. app_shell is the never-checked sequencing crash
      # (parse-error, the tier that always caught it). split_editor
      # RENDERED - its parse errors are herb heredoc strictness on sample
      # content, pinned here so any corpus drift is loud.
      def test_the_designfire_corpus_errors_close_the_required_slot_class
        failures = error_templates(DESIGNFIRE)

        assert_equal %w[app_shell command_palette menu split_editor toast], failures.keys.sort,
                     "got: #{failures.transform_values { |findings| findings.map(&:rule).uniq }}"
        missing = failures["menu"].select { |finding| finding.rule == "missing-slot" }

        assert_equal 2, missing.size, "both trigger-less menus surface, not just the first"
        assert(missing.all? { |finding| finding.message.include?("with_menu requires with_trigger") })
        assert(failures["app_shell"].any? { |finding| finding.rule == "parse-error" })
        assert_equal ["parse-error"], failures["split_editor"].map(&:rule).uniq,
                     "split_editor rendered - only herb's heredoc strictness, no contract errors"
        assert(failures["command_palette"].any? { |finding| finding.rule == "requires-any" })
        assert(failures["toast"].any? { |finding| finding.rule == "requires-any" })
      end

      # The block-path corpus: the run's two render
      # crashers - both EXACT recurrences of classes pre-named as still
      # open - now fail statically, and nothing else does (the 29-arm FP
      # guard). command_palette omitted every accessible-name path; toast
      # built a Button from label: alone (nothing visible renders).
      def test_the_blockpath_corpus_errors_on_exactly_the_two_any_of_crashers
        failures = error_templates(BLOCKPATH)

        assert_equal %w[command_palette toast], failures.keys.sort,
                     "got: #{failures.transform_values { |findings| findings.map(&:rule).uniq }}"
        palette = failures["command_palette"].find { |finding| finding.rule == "requires-any" }

        refute_nil palette
        assert_includes palette.message, "poetry_command requires one of id: / aria-label:"
        toast = failures["toast"].find { |finding| finding.rule == "requires-any" }

        refute_nil toast
        assert_includes toast.message, "poetry_button requires one of a content block"
      end

      def test_the_blocks_gate_corpus_errors_on_exactly_the_two_crashers
        failures = error_templates(BLOCKS_GATE)

        assert_equal %w[data_table site_nav], failures.keys.sort,
                     "got: #{failures.transform_values { |findings| findings.map(&:rule).uniq }}"
        assert(failures["data_table"].any? { |finding| finding.rule == "unknown-icon" },
               ":filter (lucide renamed it to funnel) must read as an icon-set miss")
        arity = failures["site_nav"].select { |finding| finding.rule == "helper-arity" }

        assert_equal 5, arity.size, "static linting sees past the first crash: poetry_link + four " \
                                    "poetry_navigation_menu_link positional-text calls all surface"
      end
    end
  end
end
