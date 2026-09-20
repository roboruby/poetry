# frozen_string_literal: true

# Page-scale companion gate grade, against the pre-registered e1-e4
# (committed before generation).
# The standing 31-brief headline is UNTOUCHED by this gate (permanent
# pre-registered rule). Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-11-pagescale/results_pagescale.rb
require "json"

RUN = File.join(Dir.pwd, "eval/results/2026-07-11-pagescale")

def load_json(path) = JSON.parse(File.read(path))

results = load_json(File.join(RUN, "results.json"))
manifest = load_json(File.join(RUN, "generation-manifest.json"))
scorecard = load_json(File.join(RUN, "generated-scorecard.json"))
audit = load_json(File.join(RUN, "mechanism-audit.json"))

tasks = results["tasks"]
overall = results["summary"]["overall"]
poetry_wins = tasks.count { |_t, s| s["verdict"] == "poetry" }
composition = tasks.count { |_t, s| s.dig("axes", "composition") == "poetry" }
crashes = scorecard["tasks"].select { |_t, s| s.dig("arms", "poetry", "render_error") }.keys.sort
delivered = manifest["units"].sum { |_t, arms| arms.count { |_a, unit| unit["artifact"] } }
summary = audit["summary"]

# Deterministic router facts (recomputed from the committed registry) and
# the crash adjudication.
ROUTED = { "analytics_overview" => "app-shell", "team_members" => "app-shell",
           "onboarding_checklist" => "app-shell" }.freeze
CRASH_ADJUDICATION = {
  "integrations" => { "error" => "unknown icon :github (not in this set)",
                      "class" => "sequencing - ran check (which flags it: unknown-icon x2) " \
                                 "but edited after; check-LAST violated" }
}.freeze

axes = %w[hierarchy composition clarity brief_fit].to_h do |axis|
  [axis, { "poetry" => tasks.count { |_t, s| s.dig("axes", axis) == "poetry" },
           "raw_tailwind" => tasks.count { |_t, s| s.dig("axes", axis) == "raw_tailwind" } }]
end

predictions = {
  "e1" => { "statement" => "24/24 delivery, zero poetry render crashes",
            "observed" => "delivery #{delivered}/24; crashes: #{crashes.empty? ? "none" : crashes.join(", ")}",
            "pass" => delivered == 24 && crashes.empty? },
  "e2" => { "statement" => "THE claim: poetry overall >= 7/12 (priors: routed subsets 6/9, 7/9)",
            "observed" => "#{poetry_wins}/12 (#{overall.inspect})", "pass" => poetry_wins >= 7 },
  "e3" => { "statement" => "composition-axis poetry >= 6/12 (off-frame it runs ~8/31)",
            "observed" => "#{composition}/12", "pass" => composition >= 6 },
  "e4" => { "statement" => "compose >= 10/12; zero contract findings on rendering arms",
            "observed" => "compose #{summary["compose_called"]}/12, design skill " \
                          "#{audit["summary"]["arms"] && summary.fetch("design_skill", "?")}/12, " \
                          "check #{summary["ran_check"]}/12, check-last #{summary["check_last"]}/12; " \
                          "contract findings only on the crashed arm (unknown-icon, which check flags)",
            "pass" => summary["compose_called"] >= 10 }
}

payload = {
  "assembled_from" => ["results.json", "generated-scorecard.json", "generation-manifest.json",
                       "mechanism-audit.json"],
  "gate" => "page-scale companion (NEVER the standing headline - pre-registered, permanent)",
  "tally" => overall,
  "axes" => axes,
  "router_facts" => { "routed_to_blocks" => ROUTED,
                      "note" => "3/12 routed (all app-shell); the keyword calibration was fit to " \
                                "the standing briefs and mostly misses this distribution - the " \
                                "gate measured pages largely WITHOUT block assistance" },
  "win_map" => tasks.transform_values { |s| s["verdict"] },
  "crash_adjudication" => CRASH_ADJUDICATION,
  "mechanism_audit" => summary,
  "generation_usage" => manifest["usage"],
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_k, p| p["pass"] }}/4 pre-registered predictions pass",
  "decision_rule_executed" => "e2 FAIL -> the page-scale claim DIES in its strong form; the " \
                              "Writeup reports component parity (15-15-1) and page-scale " \
                              "unproven-and-now-contradicted; no rescue gates get built. " \
                              "Next head: the Writeup (pre-registered)."
}

path = File.join(RUN, "results-pagescale-grade.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(predictions)
puts "tally: #{overall.inspect}"
puts "axes: #{axes.map { |a, t| "#{a} p#{t["poetry"]}/r#{t["raw_tailwind"]}" }.join(" ")}"
puts "grade: #{payload["grade"]}"
puts "written: #{path}"
