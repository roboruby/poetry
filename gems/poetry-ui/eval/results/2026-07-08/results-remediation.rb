# frozen_string_literal: true

# remediation assembly: fold the subset re-run and the theme-variant
# re-judges into eval/results/2026-07-08/results-remediation.json.
# Run from the poetry-ui root: bundle exec ruby <this file>
require "json"

ROOT = Dir.pwd
BASE = File.join(ROOT, "eval/results/2026-07-07")
REM  = File.join(ROOT, "eval/results/2026-07-08")
AFFECTED = %w[alert app_shell empty_state filter_toolbar menu].freeze

def load_json(path) = JSON.parse(File.read(path))

base_verdicts = load_json(File.join(BASE, "benchmark-verdicts.json"))["tasks"]
base_results  = load_json(File.join(BASE, "results.json"))
rem_verdicts  = load_json(File.join(REM, "benchmark-verdicts.json"))["tasks"]
themed        = load_json(File.join(REM, "benchmark-verdicts-themed.json"))["tasks"]
rem_themed    = load_json(File.join(REM, "benchmark-verdicts-remediated-themed.json"))["tasks"]
scorecard     = load_json(File.join(REM, "generated-scorecard.json"))["tasks"]
manifest      = load_json(File.join(REM, "generation-manifest.json"))

AXES = %w[hierarchy composition clarity brief_fit].freeze

def axis_winner(tally)
  return nil unless tally

  best = tally.max_by { |_, votes| votes }
  tally.values.count(best.last) > 1 ? "tied" : best.first
end

def tally_verdicts(tasks)
  tasks.values.map { |record| record["verdict"] }.tally.sort.to_h
end

def tally_axes(tasks)
  AXES.to_h do |axis|
    winners = tasks.values.map { |record| axis_winner(record.dig("axis_tallies", axis)) }
    [axis, winners.tally.sort.to_h]
  end
end

# --- the subset, before vs after ---------------------------------------
subset = AFFECTED.to_h do |task|
  arms = scorecard.dig(task, "arms") || {}
  poetry = arms["poetry"] || {}
  unit = manifest.dig("units", task, "poetry") || {}
  [task, {
    "before" => {
      "verdict" => base_verdicts.dig(task, "verdict"),
      "failure" => base_results.dig("tasks", task, "gates", "poetry") ? "render/turn failure ": nil
    },
    "after" => {
      "delivered" => unit["artifact"] == true,
      "generation" => unit.slice("cost_usd", "num_turns", "duration_s", "attempts", "error"),
      "render_error" => poetry["render_error"],
      "cross_arm_score" => poetry["cross_arm_score"],
      "verdict_default_theme" => rem_verdicts.dig(task, "verdict"),
      "verdict_themed" => rem_themed.dig(task, "verdict"),
      "swap_consistency" => rem_verdicts.dig(task, "swap_consistency")
    }
  }]
end

# --- spliced overalls ----------------------------------------------------
# remediated (default theme): original 31 with the 5 re-judged substituted
remediated = base_verdicts.merge(rem_verdicts.slice(*AFFECTED))
# themed variant of the ORIGINAL arms (31, no regeneration)
# combined "product as it stands": themed originals with remediated-themed 5
combined = themed.merge(rem_themed.slice(*AFFECTED))

payload = {
  "schema" => "results-remediation-v1",
  "headline_stands" => "'s pre-registered result (raw 18 - poetry 13) is untouched; " \
                       "everything here is a post-hoc remediation demonstration.",
  "remediation" => {
    "legs" => [
      "check value-contract tier (icon names, enum values, typed-slot props) - poetry-core b3095ee",
      "poetry-agent MCP wired into the documented workflow + benchmark host A - poetry-ui 2b5784d",
      "theme variant: same markup recaptured under vega; raw pixels reused untouched"
    ],
    "affected_tasks" => AFFECTED,
    "control" => "raw arms frozen from the pre-registered run (no resampling)"
  },
  "subset" => subset,
  "overall" => {
    "pre_registered" => base_results.dig("summary", "overall"),
    "remediated_default_theme" => tally_verdicts(remediated),
    "themed_original_arms" => tally_verdicts(themed),
    "remediated_and_themed" => tally_verdicts(combined)
  },
  "axes" => {
    "pre_registered" => base_results.dig("summary", "axes"),
    "themed_original_arms" => tally_axes(themed),
    "remediated_and_themed" => tally_axes(combined)
  },
  "usage" => {
    "generation" => manifest["usage"],
    "judge_default" => load_json(File.join(REM, "benchmark-verdicts.json")).dig("summary", "usage"),
    "judge_themed" => load_json(File.join(REM, "benchmark-verdicts-themed.json")).dig("summary", "usage"),
    "judge_remediated_themed" =>
      load_json(File.join(REM, "benchmark-verdicts-remediated-themed.json")).dig("summary", "usage")
  }
}

out = File.join(REM, "results-remediation.json")
File.write(out, JSON.pretty_generate(payload))
puts "wrote #{out}"
puts JSON.pretty_generate(payload["overall"])
