# frozen_string_literal: true

# Blocks-gate assembly (the plan note's pre-registered gate): fold the
# 10-brief re-run against the standing verdicts and grade b1-b4.
# Run from the poetry-ui root: bundle exec ruby eval/results/2026-07-09/results_blocks_gate.rb
require "json"

ROOT = Dir.pwd
BASE = File.join(ROOT, "eval/results/2026-07-07")
REM  = File.join(ROOT, "eval/results/2026-07-08")
GATE = File.join(ROOT, "eval/results/2026-07-09")

COVERED = %w[table data_table pagination user_directory filter_toolbar
             app_shell site_nav card button alert].freeze
# Standing = the best prior poetry showing per brief: the remediated
# re-judge where one exists, else the pre-registered verdict.
REMEDIATED_TASKS = %w[alert app_shell empty_state filter_toolbar menu].freeze

def load_json(path) = JSON.parse(File.read(path))

base = load_json(File.join(BASE, "results.json"))
rem_verdicts = load_json(File.join(REM, "benchmark-verdicts.json"))["tasks"]
gate_verdicts = load_json(File.join(GATE, "benchmark-verdicts.json"))["tasks"]
scorecard = load_json(File.join(GATE, "generated-scorecard.json"))["tasks"]
manifest = load_json(File.join(GATE, "generation-manifest.json"))

def axis_winner(tally)
  return nil unless tally

  best = tally.max_by { |_, votes| votes }
  tally.values.count(best.last) > 1 ? "tied" : best.first
end

def standing_for(task, base, rem_verdicts)
  if REMEDIATED_TASKS.include?(task) && rem_verdicts[task]
    { "overall" => rem_verdicts[task]["verdict"],
      "composition" => axis_winner(rem_verdicts[task].dig("axis_tallies", "composition")),
      "source" => "remediated (2026-07-08)" }
  else
    { "overall" => base.dig("tasks", task, "verdict"),
      "composition" => base.dig("tasks", task, "axes", "composition"),
      "source" => "pre-registered (2026-07-07)" }
  end
end

subset = COVERED.to_h do |task|
  gate = gate_verdicts.fetch(task)
  arm = scorecard.dig(task, "arms", "poetry") || {}
  unit = manifest.dig("units", task, "poetry") || {}
  [task, {
    "standing" => standing_for(task, base, rem_verdicts),
    "gate" => {
      "overall" => gate["verdict"],
      "composition" => axis_winner(gate.dig("axis_tallies", "composition")),
      "swap_consistency" => gate["swap_consistency"],
      "delivered" => unit["artifact"] == true,
      "render_error" => arm["render_error"],
      "cross_arm_score" => arm["cross_arm_score"],
      "design_slop" => arm.dig("cross_arm", "design_slop"),
      "generation" => unit.slice("cost_usd", "num_turns", "attempts")
    }
  }]
end

standing_comp = subset.count { |_t, row| row["standing"]["composition"] == "poetry" }
gate_comp = subset.count { |_t, row| row["gate"]["composition"] == "poetry" }
overall_flips = subset.select do |_t, row|
  row["standing"]["overall"] != "poetry" && row["gate"]["overall"] == "poetry"
end.keys
crashers = subset.select { |_t, row| row["gate"]["render_error"] }.keys
slop_failures = subset.select { |_t, row| row["gate"]["design_slop"] == false && !row["gate"]["render_error"] }.keys

predictions = {
  "b1" => { "statement" => "poetry takes the composition axis on >=5 of the 10 covered briefs",
            "baseline" => "#{standing_comp}/10 standing", "observed" => "#{gate_comp}/10",
            "pass" => gate_comp >= 5 },
  "b2" => { "statement" => ">=3 overall verdicts flip to poetry vs standing",
            "observed" => "#{overall_flips.size} flips: #{overall_flips.join(", ")}",
            "pass" => overall_flips.size >= 3 },
  "b3" => { "statement" => "no correctness regression (gate buckets + brief_fit hold)",
            "observed" => "two render-crash regressions: #{crashers.join(", ")} - both now caught " \
                          "statically (helper-arity tier; icon membership reached the resolving exe)",
            "pass" => crashers.empty? },
  "b4" => { "statement" => "poetry arms stay design_slop-clean",
            "observed" => "delivered-arm slop failures: #{slop_failures.join(", ")} " \
                          "(DesignLint on the same source: 0 findings - the gate/linter " \
                          "disagreement is itself the named finding)",
            "pass" => slop_failures.empty? }
}

payload = {
  "schema" => "results-blocks-gate-v1",
  "headline_stands" => "'s pre-registered result (raw 18 - poetry 13) and the " \
                       "remediation numbers are untouched; this is the Blocks v1 gate re-run " \
                       "the plan note pre-registered, graded against its own predictions.",
  "gate" => {
    "covered_tasks" => COVERED,
    "control" => "raw arms frozen from the pre-registered sample (copied, never resampled)",
    "surface" => [
      "AGENTS.md block-first bullet (65 components + 5 blocks)",
      "llms.txt Blocks index; llms-full.txt inlines every block's source",
      "MCP list_blocks + describe_block via .mcp.json (toolbelt extended)",
      "bin/rails g poetry:block (not runnable inside the benchmark toolbelt by design)"
    ]
  },
  "predictions" => predictions,
  "subset" => subset,
  "delivery" => {
    "first_attempt" => "10/10 (max 34 turns; the pre-registered run burned 3x40-turn samples " \
                       "on app_shell alone)",
    "rendered" => "8/10 - site_nav (helper positional-text x5) and data_table (:filter, lucide " \
                  "renamed it to funnel) crashed; both classes now fail poetry check statically"
  },
  "mechanism_audit" => {
    "describe_block_calls" => { "alert" => 1, "app_shell" => 1, "card" => 1, "data_table" => 1,
                                "filter_toolbar" => 1, "table" => 1, "button" => 0,
                                "pagination" => 0, "site_nav" => 0, "user_directory" => 0 },
    "notes" => [
      "6/10 poetry arms fetched a block via MCP; llms-full also inlines block source, so " \
      "tool counts undercount consumption",
      "app_shell's arm carries the block fingerprint (sidebar-wrapper consumer + sample " \
      "content) and flipped the overall verdict after losing 4/4 prior samples",
      "the data_table :filter PASS trace exposed the resolving-exe gap: poetry-ui's " \
      "poetry-agent shadowed poetry-core's and lacked icon injection - every prior MCP " \
      "check ran icon-shape-only; fixed + subprocess-tested same day"
    ]
  },
  "usage" => {
    "generation" => manifest["usage"],
    "judge" => load_json(File.join(GATE, "benchmark-verdicts.json")).dig("summary", "usage")
  }
}

out = File.join(GATE, "results-blocks-gate.json")
File.write(out, JSON.pretty_generate(payload))
puts "wrote #{out}"
predictions.each { |key, p| puts "#{key}: #{p["pass"] ? "PASS" : "FAIL"} - #{p["observed"]}" }
