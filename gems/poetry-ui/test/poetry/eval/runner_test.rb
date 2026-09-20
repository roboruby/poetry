# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/runner"

module Poetry
  module Eval
    class RunnerTest < Minitest::Test
      def setup
        @card = Runner.new.scorecard
      end

      def test_scorecard_covers_every_task_with_both_arms
        assert_equal Runner::TASKS.keys.sort, @card["tasks"].keys.sort
        @card["tasks"].each do |task, spec|
          assert_equal %w[poetry raw_tailwind], spec["arms"].keys.sort, "task #{task}"
        end
      end

      def test_the_full_catalog_is_exercised
        # The closeout bar: every registered component appears in at least
        # one poetry arm.
        expected = Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
                                         .components.map { |c| c.name.deconstantize.demodulize.underscore }
        missing = expected - @card["components_exercised"]

        assert_empty missing, "components missing from every poetry arm: #{missing.join(", ")}"
      end

      def test_every_poetry_arm_passes_every_cross_arm_gate
        @card["tasks"].each do |task, spec|
          cross = spec["arms"]["poetry"]["cross_arm"]

          assert_predicate cross.values, :all?, "task #{task}: #{cross.inspect}"
        end
      end

      def test_poetry_only_diagnostics_pass_and_stay_out_of_raw_arms
        @card["tasks"].each do |task, spec|
          diagnostics = spec["arms"]["poetry"]["poetry_only_diagnostics"]

          assert_predicate diagnostics.values, :all?, "task #{task}: #{diagnostics.inspect}"
          refute spec["arms"]["raw_tailwind"].key?("poetry_only_diagnostics"),
                 "poetry-only gates must never be reported against a non-poetry arm (the A/B honesty rule)"
        end
      end

      def test_raw_arms_are_realistic_not_strawmen
        # Every raw arm passes SOME gates (it is a plausible generation)
        # and fails at least one characteristic tell.
        @card["tasks"].each do |task, spec|
          cross = spec["arms"]["raw_tailwind"]["cross_arm"]

          assert_operator cross.values.count(true), :>=, 1, "task #{task}: a strawman passes nothing"
          assert_operator cross.values.count(false), :>=, 1,
                          "task #{task}: a raw arm passing everything measures nothing"
        end
      end

      def test_the_button_tells_stay_locked
        cross = @card["tasks"]["button"]["arms"]["raw_tailwind"]["cross_arm"]

        assert cross[:renders], "the raw arm is a plausible generation - it renders"
        assert cross[:accessible_name], "the raw arm has a visible label"
        refute cross[:no_raw_colors], "the arbitrary hex color is the classic raw-generation tell"
        refute cross[:explicit_type]
      end

      def test_write_emits_the_scorecard_json
        card, path = Runner.new.write!(Poetry::Ui.root.join("tmp/test-eval-scorecard.json"))

        assert_path_exists path
        parsed = JSON.parse(path.read)

        assert_equal card["tasks"].keys, parsed["tasks"].keys
        assert_includes parsed["generated_note"], "cross_arm gates are the only comparable numbers"
      ensure
        path&.delete if path&.exist?
      end
    end
  end
end
