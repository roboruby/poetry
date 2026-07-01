# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/runner"

module Poetry
  module Eval
    class RunnerTest < Minitest::Test
      def setup
        @card = Runner.new.scorecard
      end

      # The M3.5 DoD: the harness runs end-to-end and emits a scorecard.
      def test_scorecard_covers_both_arms
        assert_equal %w[poetry raw_tailwind], @card["arms"].keys.sort
      end

      def test_poetry_arm_passes_every_cross_arm_gate
        assert_equal "5/5", @card["arms"]["poetry"]["cross_arm_score"]
      end

      def test_poetry_only_diagnostics_pass_and_stay_out_of_the_raw_arm
        diagnostics = @card["arms"]["poetry"]["poetry_only_diagnostics"]

        assert_predicate diagnostics.values, :all?, diagnostics.inspect
        refute @card["arms"]["raw_tailwind"].key?("poetry_only_diagnostics"),
               "poetry-only gates must never be reported against a non-poetry arm (the A/B honesty rule)"
      end

      def test_raw_arm_fails_on_the_realistic_tells_not_strawman_gates
        cross = @card["arms"]["raw_tailwind"]["cross_arm"]

        assert cross[:renders], "the raw arm is a plausible generation - it renders"
        assert cross[:accessible_name], "the raw arm has a visible label"
        refute cross[:no_raw_colors], "the arbitrary hex color is the classic raw-generation tell"
        refute cross[:explicit_type]
      end

      def test_write_emits_the_scorecard_json
        card, path = Runner.new.write!(Poetry::Ui.root.join("tmp/test-eval-scorecard.json"))

        assert_path_exists path
        parsed = JSON.parse(path.read)

        assert_equal card["task"], parsed["task"]
        assert_includes parsed["generated_note"], "cross_arm gates are the only comparable numbers"
      ensure
        path&.delete if path&.exist?
      end
    end
  end
end
