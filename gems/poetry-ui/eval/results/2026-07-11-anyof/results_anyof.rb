# frozen_string_literal: true

# any-of contract grade: the crash-floor closer (REQUIRES_ANY +
# SLOT_RENDERS) re-gated on the 31 briefs against the pre-registered
# d1-d4 (vault note "Any-Of Contracts ", committed before
# generation). Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-11-anyof/results_anyof.rb
require "json"

RUN = File.join(Dir.pwd, "eval/results/2026-07-11-anyof")
PRIOR = File.join(Dir.pwd, "eval/results/2026-07-11-blockpath")

def load_json(path) = JSON.parse(File.read(path))

results = load_json(File.join(RUN, "results.json"))
prior = load_json(File.join(PRIOR, "results.json"))
manifest = load_json(File.join(RUN, "generation-manifest.json"))
scorecard = load_json(File.join(RUN, "generated-scorecard.json"))

tasks = results["tasks"]
overall = results["summary"]["overall"]
poetry_wins = tasks.count { |_t, s| s["verdict"] == "poetry" }
composition = tasks.count { |_t, s| s.dig("axes", "composition") == "poetry" }
crashes = scorecard["tasks"].select { |_t, s| s.dig("arms", "poetry", "render_error") }.keys.sort
delivered = manifest["units"].count { |_t, arms| arms.dig("poetry", "artifact") }

# d3: the two remediated tasks must not repeat their 4-0 sweeps.
remediated = %w[command_palette toast].to_h do |task|
  spec = tasks[task]
  contested = spec["verdict"] != "raw_tailwind" ||
              spec["axes"].values.any? { |axis| axis != "raw_tailwind" }
  [task, { "verdict" => spec["verdict"], "axes" => spec["axes"], "contested" => contested }]
end

# d4: zero requires-any FP among rendering arms - filled from the
# post-generation sweep (fresh arms linted with the committed check).
FRESH_SWEEP = load_json(File.join(RUN, "fresh-arm-sweep.json"))

flips = tasks.keys.select { |t| prior["tasks"][t] && prior["tasks"][t]["verdict"] != tasks[t]["verdict"] }
              .to_h { |t| [t, "#{prior["tasks"][t]["verdict"]} -> #{tasks[t]["verdict"]}"] }

axes = %w[hierarchy composition clarity brief_fit].to_h do |axis|
  [axis, { "poetry" => tasks.count { |_t, s| s.dig("axes", axis) == "poetry" },
           "raw_tailwind" => tasks.count { |_t, s| s.dig("axes", axis) == "raw_tailwind" } }]
end

predictions = {
  "d1" => { "statement" => "31/31 delivery, ZERO render crashes, zero pairs lost",
            "observed" => "delivery #{delivered}/31; crashes: #{crashes.empty? ? "none" : crashes.join(", ")}",
            "pass" => delivered == 31 && crashes.empty? },
  "d2" => { "statement" => "poetry overall >= 12/31 (11 - both crashed arms lost 4-0)",
            "observed" => "#{poetry_wins}/31 (#{overall.inspect})", "pass" => poetry_wins >= 12 },
  "d3" => { "statement" => "command_palette and toast are no longer 4-0 raw sweeps",
            "observed" => remediated.transform_values { |r| "#{r["verdict"]} #{r["axes"].values.tally}" },
            "pass" => remediated.values.all? { |r| r["contested"] } },
  "d4" => { "statement" => "zero requires-any findings on fresh arms that render",
            "observed" => FRESH_SWEEP["summary"],
            "pass" => FRESH_SWEEP["false_positives"].empty? }
}

payload = {
  "assembled_from" => ["results.json", "generated-scorecard.json", "generation-manifest.json",
                       "fresh-arm-sweep.json",
                       "#{PRIOR}/results.json (baseline; raw controls frozen from 2026-07-07)"],
  "headline" => overall,
  "prior_baselines" => { "dd79_blockpath" => prior["summary"]["overall"],
                         "dd78_designfire" => { "raw_tailwind" => 19, "poetry" => 11 },
                         "dd70_full" => { "raw_tailwind" => 18, "poetry" => 13 } },
  "axes" => axes,
  "composition_recorded_not_gated" => "#{composition}/31 (closed the surface ledger)",
  "verdict_changes_vs_dd79" => flips,
  "remediated_tasks" => remediated,
  "generation_usage" => manifest["usage"],
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_k, p| p["pass"] }}/4 pre-registered predictions pass",
  "decision_rule" => "this tally SUPERSEDES raw 17 - poetry 11 - inc 3 as the standing headline " \
                     "(pre-registered); no composition outcome reopens the closure"
}

path = File.join(RUN, "results-anyof-grade.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(predictions)
puts "headline: #{overall.inspect}"
puts "axes: #{axes.map { |a, t| "#{a} p#{t["poetry"]}/r#{t["raw_tailwind"]}" }.join(" ")}"
puts "grade: #{payload["grade"]}"
puts "written: #{path}"
