# frozen_string_literal: true

# design-fire grade: the generation re-run with the surfaces
# (retriggered poetry-design, three new check tiers, check-LAST) against
# the pre-registered d1-d4 (vault note "Design Fire Run ", committed
# before generation). Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-10-designfire/results_designfire.rb
require "json"

RUN = File.join(Dir.pwd, "eval/results/2026-07-10-designfire")
PRIOR = File.join(Dir.pwd, "eval/results/2026-07-09-rebaseline")

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

# The transcript mechanism audit (latest session per unit host,
# ~/.claude/projects) - run facts recorded post-generation, pre-judge.
SKILL_ADOPTION = {
  "poetry_skill_arms" => 31, "poetry_design_arms" => 24,
  "design_non_adopters" => %w[button filter_toolbar menu mobile_sheet pagination searchable_select table],
  "ran_a_check" => 26
}.freeze

# Crash adjudication (current check vs the crashed final artifacts +
# transcript sequencing): flagged = sequencing; silent = tier gap;
# pagination's invented route helper is outside poetry's static surface.
CRASH_ADJUDICATION = {
  "app_shell" => { "check" => "flagged (parse-error)", "class" => "sequencing - never ran check" },
  "menu" => { "check" => "silent (4 checks, check-last honored)",
              "class" => "tier gap: required SLOT omitted (Menubar with_trigger)" },
  "command_palette" => { "check" => "silent (checked 3x, edited after)",
                         "class" => "tier gap: accessible-name contract (Command input aria)" },
  "toast" => { "check" => "silent (1 check, check-last honored)",
               "class" => "tier gap: conditional content (Button renders nothing visible)" },
  "pagination" => { "check" => "silent - and never ran check",
                    "class" => "uncheckable: invented host route helper (eval_pagination_path)" }
}.freeze

flips = tasks.keys.select { |t| prior["tasks"][t] && prior["tasks"][t]["verdict"] != tasks[t]["verdict"] }
              .to_h { |t| [t, "#{prior["tasks"][t]["verdict"]} -> #{tasks[t]["verdict"]}"] }

axes = %w[hierarchy composition clarity brief_fit].to_h do |axis|
  [axis, { "poetry" => tasks.count { |_t, s| s.dig("axes", axis) == "poetry" },
           "raw_tailwind" => tasks.count { |_t, s| s.dig("axes", axis) == "raw_tailwind" } }]
end

predictions = {
  "d1" => { "statement" => "poetry-design fires >= 20/31 (was 0) AND usage skill >= 27/31",
            "observed" => "design #{SKILL_ADOPTION["poetry_design_arms"]}/31, " \
                          "usage #{SKILL_ADOPTION["poetry_skill_arms"]}/31",
            "pass" => SKILL_ADOPTION["poetry_design_arms"] >= 20 && SKILL_ADOPTION["poetry_skill_arms"] >= 27 },
  "d2" => { "statement" => "composition-axis tally >= 10 of 31 (5;: 9)",
            "observed" => "#{composition}/31", "pass" => composition >= 10 },
  "d3" => { "statement" => "poetry overall >= 14 of 31 (12)",
            "observed" => "#{poetry_wins}/31 (#{overall.inspect})", "pass" => poetry_wins >= 14 },
  "d4" => { "statement" => "31/31 delivery, zero render crashes, zero pairs lost",
            "observed" => "delivery #{delivered}/31; crashes: #{crashes.join(", ")}",
            "pass" => delivered == 31 && crashes.empty? }
}

payload = {
  "assembled_from" => ["results.json", "generated-scorecard.json", "generation-manifest.json",
                       "#{PRIOR}/results.json (baseline; raw controls frozen from 2026-07-07)"],
  "headline" => overall,
  "prior_baselines" => { "dd75_depth3_and_depth5_confirmed" => prior["summary"]["overall"],
                         "dd70_full" => { "raw_tailwind" => 18, "poetry" => 13 } },
  "axes" => axes,
  "verdict_changes_vs_dd75" => flips,
  "skill_adoption" => SKILL_ADOPTION,
  "crash_adjudication" => CRASH_ADJUDICATION,
  "generation_usage" => manifest["usage"],
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_k, p| p["pass"] }}/4 pre-registered predictions pass",
  "decision_rule" => "this tally SUPERSEDES 16-12-3 as the standing headline (pre-registered)"
}

path = File.join(RUN, "results-designfire-grade.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(predictions)
puts "headline: #{overall.inspect}"
puts "axes: #{axes.map { |a, t| "#{a} p#{t["poetry"]}/r#{t["raw_tailwind"]}" }.join(" ")}"
puts "grade: #{payload["grade"]}"
puts "written: #{path}"
