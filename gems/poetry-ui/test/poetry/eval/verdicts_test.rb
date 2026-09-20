# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"
require_relative "../../../eval/verdicts"

module Poetry
  module Eval
    class VerdictsTest < Minitest::Test
      RESULTS = {
        "card" => { "verdict" => "poetry", "swap_consistency" => 1.0 },
        "form" => { "verdict" => "tie", "swap_consistency" => 0.5 }
      }.freeze

      def test_merge_returns_the_run_as_given_without_a_file
        Dir.mktmpdir do |dir|
          results, usage = Verdicts.merge(Pathname(dir).join("none.json"), RESULTS, { "judge_calls" => 4,
                                                                                      "total_cost_usd" => 0.2 })

          assert_equal RESULTS, results
          assert_equal 4, usage["judge_calls"]
        end
      end

      def test_merge_replaces_rejudged_tasks_keeps_the_rest_and_accumulates_usage
        Dir.mktmpdir do |dir|
          path = Pathname(dir).join("verdicts.json")
          path.write(JSON.generate("tasks" => { "card" => { "verdict" => "raw", "swap_consistency" => 0.0 },
                                                "table" => { "verdict" => "poetry", "swap_consistency" => 1.0 } },
                                   "summary" => { "usage" => { "judge_calls" => 6, "total_cost_usd" => 0.3 } }))

          results, usage = Verdicts.merge(path, RESULTS, { "judge_calls" => 4, "total_cost_usd" => 0.2 })

          assert_equal %w[card form table], results.keys.sort
          assert_equal "poetry", results["card"]["verdict"], "the re-judged task replaces its record"
          assert_equal({ "judge_calls" => 10, "total_cost_usd" => 0.5 }, usage)
        end
      end

      def test_summary_tallies_verdicts_and_averages_swap_consistency
        summary = Verdicts.summary(RESULTS, { "judge_calls" => 4 })

        assert_equal({ "poetry" => 1, "tie" => 1 }, summary["verdicts"])
        assert_in_delta 0.75, summary["mean_swap_consistency"]
        assert_equal 4, summary.dig("usage", "judge_calls")
      end
    end
  end
end
