# frozen_string_literal: true

require "json"

# The eval results the Evals page shows: one row per judged run stored
# under poetry-ui's eval/results, each with the uncertainty its sample
# size allows. The harness and its results live in the monorepo and are
# not shipped in any gem, so the page reads a committed copy
# (data/eval-ledger.json) that `rake poetry_docs:eval_ledger` builds from
# the result files; a test fails when the copy is stale.
#
# A run generates each brief once, so a count like 13 of 31 is one draw.
# Every share here carries a 95% Wilson interval for that reason: it is
# the honest width of the claim, and at these sizes it is wide.
#
# @example
#   EvalLedger.wilson(13, 31) # => [0.264, 0.592]
module Poetry
  module Docs
    class EvalLedger
      # The committed copy the page reads.
      PATH = Poetry::Docs.root.join("data/eval-ledger.json")
      # The normal quantile of a 95% interval.
      Z = 1.959964
      # The arm names the result files use, and the ledger's.
      ARMS = { "poetry" => "poetry", "raw_tailwind" => "raw" }.freeze

      # Where the harness stores its runs.
      def self.results_root
        Poetry::Docs.root.join("../poetry-ui/eval/results").expand_path
      end

      # The ledger as the page reads it.
      def self.read
        JSON.parse(PATH.read)
      end

      # Builds the ledger from the stored runs and writes the committed copy.
      def self.write!(root = results_root)
        PATH.write("#{JSON.pretty_generate(build(root))}\n")
        build(root).fetch("runs").size
      end

      # The ledger built from the stored runs: every judged run in name
      # order, then the long-conversation run when one is stored.
      def self.build(root = results_root)
        runs = Pathname(root).glob("*/benchmark-verdicts.json").sort.map { |file| run(file.dirname) }
        degradation = Pathname(root).glob("*/degradation-results.json").max
        { "runs" => runs, "degradation" => degradation && long_run(degradation) }.compact
      end

      # The 95% Wilson score interval for a share of successes, to three
      # places. It stays inside 0..1 and behaves at small counts, which the
      # plain normal interval does not.
      def self.wilson(successes, total)
        return nil if total.zero?

        share = successes.fdiv(total)
        denominator = 1 + ((Z**2) / total)
        centre = share + ((Z**2) / (2 * total))
        spread = Z * Math.sqrt(((share * (1 - share)) / total) + ((Z**2) / (4 * (total**2))))
        [ ((centre - spread) / denominator).round(3), ((centre + spread) / denominator).round(3) ]
      end

      # One judged run: what the judge decided, how sure the count can be,
      # and, when the run stored them, the axes, the checks and the cost.
      def self.run(dir)
        verdicts = JSON.parse(dir.join("benchmark-verdicts.json").read)
        tally = verdicts.fetch("tasks").values.map { |task| task["verdict"] }.tally
        poetry = tally.fetch("poetry", 0)
        raw = tally.fetch("raw_tailwind", 0)
        row = { "id" => dir.basename.to_s, "briefs" => verdicts.fetch("tasks").size, "model" => verdicts["model"],
                "poetry" => poetry, "raw" => raw, "inconclusive" => tally.values.sum - poetry - raw,
                "share" => (poetry + raw).zero? ? nil : poetry.fdiv(poetry + raw).round(3),
                "interval" => wilson(poetry, poetry + raw) }
        row.merge(details(dir.join("results.json"))).compact
      end

      # What a run's results file adds, when it has one.
      def self.details(file)
        return {} unless file.file?

        results = JSON.parse(file.read)
        { "axes" => axes(results.dig("summary", "axes")), "checks" => checks(results.fetch("tasks", {})),
          "cost_usd" => results.dig("meta", "generation", "receipted_cost_usd") }
      end

      # The judge's per-axis tallies under the ledger's arm names.
      def self.axes(axes)
        axes&.transform_values do |tally|
          { "poetry" => tally.fetch("poetry", 0), "raw" => tally.fetch("raw_tailwind", 0), "tied" => tally.fetch("tied", 0) }
        end
      end

      # The mechanical checks each arm's pages passed, counting only the
      # checks both arms of a brief were scored on: a check that one arm
      # cannot fail is no comparison.
      def self.checks(tasks)
        counts = ARMS.values.to_h { |arm| [ arm, { "passed" => 0, "of" => 0 } ] }
        tasks.each_value do |task|
          gates = task["gates"] || {}
          shared = ARMS.keys.map { |arm| (gates[arm] || {}).keys }.reduce(:&)
          ARMS.each do |source, arm|
            counts[arm]["of"] += shared.size
            counts[arm]["passed"] += shared.count { |gate| gates[source][gate] == true }
          end
        end
        return nil if counts.values.all? { |count| count["of"].zero? }

        counts.transform_values { |count| count.merge("rate" => count["passed"].fdiv(count["of"]).round(3)) }
      end

      # The long-conversation run: the share of checks each arm passed at
      # each probe, and how many briefs the judge preferred Poetry on.
      def self.long_run(file)
        results = JSON.parse(file.read)
        summary = results.fetch("summary")
        { "id" => file.dirname.basename.to_s, "briefs" => results.fetch("tasks").size,
          "pass_rates" => summary.fetch("probe_pass_rates").to_h { |arm, rates| [ ARMS.fetch(arm, arm), rates ] },
          "judged_poetry_wins" => summary["judged_poetry_wins"] }
      end

      private_class_method :run, :details, :axes, :checks, :long_run
    end
  end
end
