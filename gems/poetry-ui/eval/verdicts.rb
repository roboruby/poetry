# frozen_string_literal: true

require "json"

module Poetry
  module Eval
    # A judge run's verdicts: the results folded into an existing file of
    # the same name (a subset re-run replaces its tasks, the rest stand,
    # usage accumulates - a single-task re-run never clobbers a
    # calibration), and the summary every verdict payload carries.
    module Verdicts
      module_function

      # The usage a judge reports for the run it just made.
      def usage_of(judge)
        { "judge_calls" => judge.calls, "total_cost_usd" => judge.total_cost_usd.round(4) }
      end

      # The results and usage merged over what the file already holds, or
      # as given when there is no file.
      def merge(path, results, usage)
        return [results, usage] unless path.exist?

        previous = JSON.parse(path.read)
        before = previous.dig("summary", "usage") || {}
        merged_usage = {
          "judge_calls" => before.fetch("judge_calls", 0) + usage["judge_calls"],
          "total_cost_usd" => (before.fetch("total_cost_usd", 0.0) + usage["total_cost_usd"]).round(4)
        }
        [previous.fetch("tasks", {}).merge(results), merged_usage]
      end

      # The verdict tally, the mean swap consistency and the usage.
      def summary(results, usage)
        {
          "verdicts" => results.values.group_by { |record| record["verdict"] }.transform_values(&:size),
          "mean_swap_consistency" =>
            (results.values.sum { |record| record["swap_consistency"] } / results.size).round(3),
          "usage" => usage
        }
      end
    end
  end
end
