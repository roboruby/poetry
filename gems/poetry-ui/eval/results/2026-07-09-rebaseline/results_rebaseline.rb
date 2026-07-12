# frozen_string_literal: true

# re-baseline assembly: grade the pre-registered d1-d4 (vault plan
# note, committed before generation) against the full 31-brief run with a
# skill-equipped poetry arm vs the FROZEN 2026-07-07 raw controls.
# Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-09-rebaseline/results_rebaseline.rb
require "json"

ROOT = Dir.pwd
RUN = File.join(ROOT, "eval/results/2026-07-09-rebaseline")
DD70 = File.join(ROOT, "eval/results/2026-07-07")

def load_json(path) = JSON.parse(File.read(path))

results = load_json(File.join(RUN, "results.json"))
dd70 = load_json(File.join(DD70, "results.json"))
manifest = load_json(File.join(RUN, "generation-manifest.json"))
scorecard = load_json(File.join(RUN, "generated-scorecard.json"))

tasks = results["tasks"]
overall = results["summary"]["overall"]
poetry_wins = tasks.count { |_t, s| s["verdict"] == "poetry" }
composition = tasks.count { |_t, s| s.dig("axes", "composition") == "poetry" }
crashes = scorecard["tasks"].select { |_t, s| s.dig("arms", "poetry", "render_error") }.keys.sort
delivered = manifest["units"].count { |_t, arms| arms.dig("poetry", "artifact") }

# The transcript mechanism audit (scratchpad dd75_mechanism_audit.rb over
# ~/.claude/projects session logs, latest session per unit host) - counts
# recorded here as run facts.
SKILL_ADOPTION = { "poetry_skill_arms" => 29, "poetry_design_arms" => 0,
                   "non_adopters" => %w[date_field upload_progress],
                   "ran_a_check" => 30 }.freeze

# Crash adjudication: current `poetry check` run against each crashed
# artifact after the run. flagged = sequencing failure (the tool catches
# it; the agent finished without a final check). silent = tier gap.
CRASH_ADJUDICATION = {
  "chat_transcript" => { "check" => "flagged (3 parse errors)", "class" => "sequencing - never ran check" },
  "filter_toolbar" => { "check" => "flagged (unknown-variant align)", "class" => "sequencing - checked then edited" },
  "menu" => { "check" => "silent", "class" => "tier gap: slot builder called on nil receiver" },
  "floating" => { "check" => "silent", "class" => "tier gap: required content block absent" },
  "artwork_carousel" => { "check" => "silent", "class" => "tier gap: unknown kwarg :class on a setter" }
}.freeze

flips = tasks.keys.select { |t| dd70["tasks"][t] && dd70["tasks"][t]["verdict"] != tasks[t]["verdict"] }
                  .to_h { |t| [t, "#{dd70["tasks"][t]["verdict"]} -> #{tasks[t]["verdict"]}"] }

axes = %w[hierarchy composition clarity brief_fit].to_h do |axis|
  [axis, { "poetry" => tasks.count { |_t, s| s.dig("axes", axis) == "poetry" },
           "raw_tailwind" => tasks.count { |_t, s| s.dig("axes", axis) == "raw_tailwind" } }]
end

predictions = {
  "d1" => { "statement" => "poetry overall wins >= 16 of 31 (13; remediated fold: 15)",
            "observed" => "#{poetry_wins}/31 (#{overall.inspect})", "pass" => poetry_wins >= 16 },
  "d2" => { "statement" => "poetry composition-axis tally >= 14 of 31 (9)",
            "observed" => "#{composition}/31", "pass" => composition >= 14 },
  "d3" => { "statement" => ">= 20 of 31 poetry arms invoke a poetry skill unprompted",
            "observed" => "#{SKILL_ADOPTION["poetry_skill_arms"]}/31 (poetry-design: " \
                          "#{SKILL_ADOPTION["poetry_design_arms"]})",
            "pass" => SKILL_ADOPTION["poetry_skill_arms"] >= 20 },
  "d4" => { "statement" => "31/31 first-attempt delivery, zero render crashes, zero check-crashers",
            "observed" => "delivery #{delivered}/31; render crashes: #{crashes.join(", ")}",
            "pass" => delivered == 31 && crashes.empty? }
}

payload = {
  "assembled_from" => ["results.json", "generated-scorecard.json", "generation-manifest.json",
                       "#{DD70}/results.json (frozen baseline + controls)"],
  "headline" => overall,
  "prior_baselines" => { "dd70_full" => dd70["summary"]["overall"],
                         "dd71_remediated_fold" => { "raw_tailwind" => 16, "poetry" => 15 } },
  "axes" => axes,
  "verdict_changes_vs_dd70" => flips,
  "skill_adoption" => SKILL_ADOPTION,
  "crash_adjudication" => CRASH_ADJUDICATION,
  "generation_usage" => manifest["usage"],
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_k, p| p["pass"] }}/4 pre-registered predictions pass"
}

path = File.join(RUN, "results-rebaseline.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(payload["predictions"])
puts "grade: #{payload["grade"]}"
puts "written: #{path}"
