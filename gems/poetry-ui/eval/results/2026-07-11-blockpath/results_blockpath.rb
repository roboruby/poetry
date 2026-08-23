# frozen_string_literal: true

# Block-default-path grade: the run testing whether making blocks
# the DEFAULT path (compose entry point + required-slot tier + compose-
# first surfaces) moves the composition axis the design-fire run proved
# prose cannot. Graded against the pre-registered d1-d4 (committed
# before generation). Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-11-blockpath/results_blockpath.rb
require "json"

RUN = File.join(Dir.pwd, "eval/results/2026-07-11-blockpath")
PRIOR = File.join(Dir.pwd, "eval/results/2026-07-10-designfire")

def load_json(path) = JSON.parse(File.read(path))

results = load_json(File.join(RUN, "results.json"))
prior = load_json(File.join(PRIOR, "results.json"))
manifest = load_json(File.join(RUN, "generation-manifest.json"))
scorecard = load_json(File.join(RUN, "generated-scorecard.json"))
audit = load_json(File.join(RUN, "mechanism-audit.json"))

tasks = results["tasks"]
overall = results["summary"]["overall"]
poetry_wins = tasks.count { |_t, s| s["verdict"] == "poetry" }
composition = tasks.count { |_t, s| s.dig("axes", "composition") == "poetry" }
crashes = scorecard["tasks"].select { |_t, s| s.dig("arms", "poetry", "render_error") }.keys.sort
delivered = manifest["units"].count { |_t, arms| arms.dig("poetry", "artifact") }

# The transcript mechanism audit (mechanism-audit.json, recorded post-
# generation, pre-judge - underscores munge to hyphens in project dirs).
summary = audit["summary"]

# Block-descent receipts for the 9 router-matched briefs: verbatim-line
# overlap with the routed block template (a LOWER bound - replaced sample
# content stops matching), plus the outer structural frame. Adjudicated
# descent = frame kept or >= 20% verbatim.
BLOCK_DESCENT = {
  "app_shell" => { "block" => "app-shell", "verbatim" => "67/67", "descent" => true },
  "site_nav" => { "block" => "top-nav", "verbatim" => "25/25", "descent" => true },
  "table" => { "block" => "data-index", "verbatim" => "18/52", "descent" => true },
  "card" => { "block" => "section-card", "verbatim" => "6/24", "descent" => true },
  "data_table" => { "block" => "data-index", "verbatim" => "11/52", "descent" => true },
  "filter_toolbar" => { "block" => "data-index", "verbatim" => "3/52", "descent" => false },
  "form_controls" => { "block" => "section-card", "verbatim" => "1/24", "descent" => false },
  "settings_tabs" => { "block" => "section-card", "verbatim" => "1/24", "descent" => false },
  "user_directory" => { "block" => "data-index", "verbatim" => "0/52", "descent" => false }
}.freeze

# Crash adjudication (render errors vs check tiers + transcripts): both
# crashes are EXACT recurrences of the two design-fire classes the cut
# deliberately left open (conditional any-of contracts). The
# closed classes held: menu (required-slot tier), app_shell (checked this
# run), pagination (no invented helpers).
CRASH_ADJUDICATION = {
  "command_palette" => { "error" => "Command requires an accessible name for its input",
                         "class" => "open design-fire class: accessible-name contract" },
  "toast" => { "error" => "Button renders nothing visible (icon-only without label path)",
               "class" => "open design-fire class: conditional content" }
}.freeze

flips = tasks.keys.select { |t| prior["tasks"][t] && prior["tasks"][t]["verdict"] != tasks[t]["verdict"] }
                  .to_h { |t| [t, "#{prior["tasks"][t]["verdict"]} -> #{tasks[t]["verdict"]}"] }

axes = %w[hierarchy composition clarity brief_fit].to_h do |axis|
  [axis, { "poetry" => tasks.count { |_t, s| s.dig("axes", axis) == "poetry" },
           "raw_tailwind" => tasks.count { |_t, s| s.dig("axes", axis) == "raw_tailwind" } }]
end

predictions = {
  "d1" => { "statement" => "blocks-surface adoption >= 15/31 (design-fire: 3/31); recorded: compose >= 12",
            "observed" => "blocks surface #{summary["blocks_surface"]}/31, " \
                          "compose #{summary["compose_called"]}/31, " \
                          "check #{summary["ran_check"]}/31, check-last #{summary["check_last"]}/31",
            "pass" => summary["blocks_surface"] >= 15 },
  "d2" => { "statement" => "composition-axis tally >= 10/31 (re-baseline: 5; design-fire: 6; baseline: raw won 21-9)",
            "observed" => "#{composition}/31", "pass" => composition >= 10 },
  "d3" => { "statement" => "poetry overall >= 14/31 (design-fire: 11)",
            "observed" => "#{poetry_wins}/31 (#{overall.inspect})", "pass" => poetry_wins >= 14 },
  "d4" => { "statement" => "31/31 delivery, zero render crashes, zero pairs lost",
            "observed" => "delivery #{delivered}/31; crashes: #{crashes.join(", ")}",
            "pass" => delivered == 31 && crashes.empty? }
}

payload = {
  "assembled_from" => ["results.json", "generated-scorecard.json", "generation-manifest.json",
                       "mechanism-audit.json",
                       "#{PRIOR}/results.json (design-fire baseline; raw controls frozen from 2026-07-07)"],
  "headline" => overall,
  "prior_baselines" => { "designfire_run" => prior["summary"]["overall"],
                         "rebaseline_depth_confirmed" => { "raw_tailwind" => 16, "poetry" => 12 },
                         "baseline_full" => { "raw_tailwind" => 18, "poetry" => 13 } },
  "axes" => axes,
  "verdict_changes_vs_dd78" => flips,
  "mechanism_audit" => summary,
  "block_descent" => BLOCK_DESCENT,
  "crash_adjudication" => CRASH_ADJUDICATION,
  "generation_usage" => manifest["usage"],
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_k, p| p["pass"] }}/4 pre-registered predictions pass",
  "decision_rule" => "this tally SUPERSEDES raw 19 - poetry 11 - inc 1 as the standing headline " \
                     "(pre-registered)"
}

path = File.join(RUN, "results-blockpath-grade.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(predictions)
puts "headline: #{overall.inspect}"
puts "axes: #{axes.map { |a, t| "#{a} p#{t["poetry"]}/r#{t["raw_tailwind"]}" }.join(" ")}"
puts "block descent: #{BLOCK_DESCENT.count { |_t, d| d["descent"] }}/9 routed briefs"
puts "grade: #{payload["grade"]}"
puts "written: #{path}"
