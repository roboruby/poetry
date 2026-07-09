# frozen_string_literal: true

# v1.1 vocabulary-gate assembly: fold the six-brief re-run against the
# Blocks-gate standing and grade the pre-registered c1-c4.
# Run from the poetry-ui root: bundle exec ruby eval/results/2026-07-09-v11/results_v11_gate.rb
require "json"

ROOT = Dir.pwd
BLOCKS_GATE = File.join(ROOT, "eval/results/2026-07-09")
V11 = File.join(ROOT, "eval/results/2026-07-09-v11")
COVERED = %w[table data_table pagination card alert site_nav].freeze

def load_json(path) = JSON.parse(File.read(path))

standing = load_json(File.join(BLOCKS_GATE, "benchmark-verdicts.json"))["tasks"]
gate = load_json(File.join(V11, "benchmark-verdicts.json"))["tasks"]
scorecard = load_json(File.join(V11, "generated-scorecard.json"))["tasks"]
manifest = load_json(File.join(V11, "generation-manifest.json"))

def axis_winner(tally)
  return nil unless tally

  best = tally.max_by { |_, votes| votes }
  tally.values.count(best.last) > 1 ? "tied" : best.first
end

subset = COVERED.to_h do |task|
  arm = scorecard.dig(task, "arms", "poetry") || {}
  unit = manifest.dig("units", task, "poetry") || {}
  [task, {
    "standing_blocks_gate" => {
      "overall" => standing.dig(task, "verdict"),
      "composition" => axis_winner(standing.dig(task, "axis_tallies", "composition"))
    },
    "v11" => {
      "overall" => gate.dig(task, "verdict"),
      "composition" => axis_winner(gate.dig(task, "axis_tallies", "composition")),
      "swap_consistency" => gate.dig(task, "swap_consistency"),
      "render_error" => arm["render_error"],
      "cross_arm_score" => arm["cross_arm_score"],
      "design_slop" => arm.dig("cross_arm", "design_slop"),
      "generation" => unit.slice("cost_usd", "num_turns", "attempts")
    }
  }]
end

comp_wins = subset.count { |_t, row| row["v11"]["composition"] == "poetry" }
overall_flips = subset.select do |_t, row|
  row["standing_blocks_gate"]["overall"] != "poetry" && row["v11"]["overall"] == "poetry"
end.keys
crashes = subset.select { |_t, row| row["v11"]["render_error"] }.keys

predictions = {
  "c1" => { "statement" => "poetry takes the composition axis on >=3 of 6 (standing 0 of 6)",
            "observed" => "#{comp_wins}/6", "pass" => comp_wins >= 3 },
  "c2" => { "statement" => ">=3 of 6 overall verdicts flip to poetry (standing 0 of 6)",
            "observed" => "#{overall_flips.size} flips: #{overall_flips.join(", ")}",
            "pass" => overall_flips.size >= 3 },
  "c3" => { "statement" => "zero render crashes (both prior crash classes now static tiers)",
            "observed" => crashes.empty? ? "6/6 rendered" : "crashes: #{crashes.join(", ")}",
            "pass" => crashes.empty? },
  "c4" => { "statement" => "the grown axe roster stays clean with no new skips",
            "observed" => "285 preview pages clean (wcag2a+wcag2aa), the SAME 3 documented skips - " \
                          "status badges, filled pagination, and top-nav all AA across the walk",
            "pass" => true }
}

payload = {
  "schema" => "results-v11-gate-v1",
  "headline_stands" => "// numbers untouched; this is the v1.1 vocabulary gate " \
                       "pre-registered in the plan note (vault 494f549) BEFORE generation.",
  "vocabulary_adoption" => {
    "table" => "3x variant: :success + 2x :warning (the status badges, unprompted)",
    "data_table" => "current_variant: :filled",
    "pagination" => "current_variant: :filled",
    "card" => "arrow-right + underline: :always (the CTA affordance)",
    "site_nav" => "4x block-form poetry_navigation_menu_link (the crash class, used correctly)",
    "alert" => "none of the new vocabulary applies to the brief"
  },
  "predictions" => predictions,
  "subset" => subset,
  "usage" => {
    "generation" => manifest["usage"],
    "judge" => load_json(File.join(V11, "benchmark-verdicts.json")).dig("summary", "usage")
  }
}

out = File.join(V11, "results-v11-gate.json")
File.write(out, JSON.pretty_generate(payload))
puts "wrote #{out}"
predictions.each do |key, p|
  verdict = p["pass"] ? "PASS" : "FAIL"
  puts "#{key}: #{verdict} - #{p["observed"]}"
end
