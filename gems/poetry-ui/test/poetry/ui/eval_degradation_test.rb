# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/runner"
require_relative "../../../eval/degradation"
require_relative "../../../eval/holdout"

module Poetry
  module Ui
    # The degradation rig, pinned without any CLI: the protocol shape
    # IS the pre-registration (changing SEQUENCE/SAMPLE/FOLLOW_UPS is a new
    # pre-registration), every authored prompt stays hermetic, and the
    # aggregate math (slopes, cliffs, predictions) is pure and testable on
    # synthetic fixtures. The holdout stratum's shape is pinned here too.
    class EvalDegradationTest < Minitest::Test
      DEG = Poetry::Eval::Degradation

      def test_the_sample_is_ten_standing_briefs_with_two_follow_ups_each
        assert_equal 10, DEG::SAMPLE.size
        assert_empty DEG::SAMPLE - Poetry::Eval::Runner::TASKS.keys, "sample must be standing briefs"
        assert_equal DEG::SAMPLE.sort, DEG::FOLLOW_UPS.keys.sort
        DEG::FOLLOW_UPS.each_value { |edits| assert_equal 2, edits.size }
      end

      def test_the_protocol_sequence_is_the_pre_registered_shape
        probes = DEG::SEQUENCE.select { |step, _kind, _index| step == :probe }.map { |_s, kind, _i| kind }

        assert_equal %w[p0 p1 p2], probes
        # p0 immediately after the brief; p1 after the first follow-up;
        # p2 terminal after the second.
        assert_equal [:message, "brief", nil], DEG::SEQUENCE.first
        assert_equal [:probe, "p0"], DEG::SEQUENCE[1]
        assert_equal [:probe, "p2"], DEG::SEQUENCE.last
        follow_up_positions = DEG::SEQUENCE.each_index.select { |i| DEG::SEQUENCE[i][1] == "follow_up" }

        follow_up_positions.each do |i|
          assert_equal :probe, DEG::SEQUENCE[i + 1].first, "every follow-up is immediately probed"
        end
        kinds = DEG::SEQUENCE.select { |step, _k, _i| step == :message }.map { |_s, kind, _i| kind }

        assert_equal DEG::BUDGETS.keys.sort, kinds.uniq.sort, "every message kind carries a budget"
        assert_equal 4, kinds.count("filler")
        assert_equal 1, kinds.count("distractor")
      end

      def test_every_authored_prompt_is_hermetic
        needle = DEG::HERMETIC_NEEDLE
        strings = DEG::FILLERS + [DEG::DISTRACTOR] + DEG::FOLLOW_UPS.values.flatten +
                  Poetry::Eval::Holdout::TASKS.values.map { |spec| spec["description"] }

        strings.each do |text|
          refute_includes text.downcase, needle, "authored prompt leaks the house name: #{text[0, 60]}"
        end
      end

      def test_fillers_are_chat_only_by_instruction
        DEG::FILLERS.each do |filler|
          assert_match(/chat/i, filler)
          assert_match(/no file|do not read or modify|touch nothing|no files/i, filler)
        end
      end

      def test_the_placeholder_matches_the_benchmark_harvest_placeholder
        # aggregate's delivered check depends on string equality with what
        # harvest writes for an absent artifact.
        assert_equal "<%# generation produced no artifact %>\n", DEG::PLACEHOLDER
      end

      def test_the_holdout_stratum_shape_and_doctrine
        tasks = Poetry::Eval::Holdout::TASKS

        assert_equal 8, tasks.size
        assert_empty tasks.keys & Poetry::Eval::Runner::TASKS.keys, "holdout tasks never shadow standing briefs"
        tasks.each do |name, spec|
          assert_operator spec["description"].length, :>, 40, "#{name}: a real brief, not a stub"
          assert_operator spec["gates"].size, :>=, 3, "#{name}: enough gates to grade"
          spec["gates"].each { |gate| assert_equal :cross_arm, gate.scope, "#{name}: holdout gates are comparable" }
        end

        assert_match(/NEVER tune/i, File.read(File.expand_path("../../../eval/holdout.rb", __dir__)))
      end

      def test_aggregate_computes_slopes_cliffs_and_predictions
        gates = { "a" => true, "b" => true, "c" => true }
        degraded = { "a" => true, "b" => false, "c" => false }
        scorecards = {
          "p0" => fixture_scorecard(poetry: gates, raw: gates),
          "p1" => fixture_scorecard(poetry: gates, raw: gates),
          "p2" => fixture_scorecard(poetry: gates, raw: degraded)
        }
        verdicts = {
          "p0" => { "tasks" => { "button" => { "verdict" => "poetry" } } },
          "p2" => { "tasks" => { "button" => { "verdict" => "poetry" } } }
        }
        manifest = { "units" => { "button" => { "poetry" => { "messages" => [] },
                                                "raw_tailwind" => { "messages" => [] } } } }
        artifacts = {
          "p0" => { "button" => { "poetry" => "<%= poetry_button %><%= poetry_icon %>", "raw_tailwind" => "<div>" } },
          "p1" => { "button" => { "poetry" => "<%= poetry_button %><%= poetry_icon %>", "raw_tailwind" => "<div>" } },
          "p2" => { "button" => { "poetry" => "<%= poetry_button %>", "raw_tailwind" => "<div>" } }
        }

        payload = DEG.aggregate(scorecards: scorecards, verdicts: verdicts,
                                manifest: manifest, artifacts: artifacts)
        summary = payload["summary"]

        assert_equal "degradation-v1", payload["schema"]
        assert_in_delta 0.0, summary["drop_p0_to_p2"]["poetry"]
        assert_in_delta((1.0 - 1.fdiv(3)).round(3), summary["drop_p0_to_p2"]["raw_tailwind"])
        # The raw arm lost two p0-passing gates at p2 - that IS the cliff.
        assert_equal({ "p2" => 1 }, summary["cliffs"]["raw_tailwind"])
        assert_equal({ nil => 1 }, summary["cliffs"]["poetry"])
        # Helper survival: 1 call at p2 vs 2 at p0 = exactly 50%, survives.
        assert summary["helper_survival"]["button"]["survived"]
        predictions = summary["predictions"]

        assert predictions["p1_delivery"]["pass"]
        assert predictions["p2_slope"]["pass"]
        assert predictions["p3_judged_survival"]["pass"]
        assert predictions["p4_distractor_resistance"]["pass"]
      end

      def test_aggregate_fails_the_right_predictions_when_the_poetry_arm_degrades
        gates = { "a" => true, "b" => true, "c" => true }
        collapsed = { "a" => false, "b" => false, "c" => true }
        scorecards = {
          "p0" => fixture_scorecard(poetry: gates, raw: gates),
          "p1" => fixture_scorecard(poetry: gates, raw: gates),
          "p2" => fixture_scorecard(poetry: collapsed, raw: gates)
        }
        verdicts = {
          "p0" => { "tasks" => { "button" => { "verdict" => "poetry" } } },
          "p2" => { "tasks" => { "button" => { "verdict" => "raw_tailwind" } } }
        }
        manifest = { "units" => { "button" => { "poetry" => {}, "raw_tailwind" => {} } } }
        artifacts = {
          "p0" => { "button" => { "poetry" => "<%= poetry_button %><%= poetry_icon %>", "raw_tailwind" => "<div>" } },
          "p1" => { "button" => { "poetry" => "<%= poetry_button %>", "raw_tailwind" => "<div>" } },
          "p2" => { "button" => { "poetry" => "<div class='p-4'>", "raw_tailwind" => "<div>" } }
        }

        summary = DEG.aggregate(scorecards: scorecards, verdicts: verdicts,
                                manifest: manifest, artifacts: artifacts)["summary"]

        refute summary["predictions"]["p2_slope"]["pass"]
        # p3 tolerates a drop of exactly one win (1 -> 0 here): still passes.
        assert summary["predictions"]["p3_judged_survival"]["pass"]
        refute summary["predictions"]["p4_distractor_resistance"]["pass"]
      end

      private

      def fixture_scorecard(poetry:, raw:)
        { "tasks" => { "button" => { "arms" => {
          "poetry" => { "cross_arm" => poetry },
          "raw_tailwind" => { "cross_arm" => raw }
        } } } }
      end
    end
  end
end
