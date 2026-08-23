# frozen_string_literal: true

# Vote-depth grade: the depth-5 re-judge of the SAME 31 capture pairs
# against the pre-registered d1-d4 (committed before the run) and the
# pre-registered decision rule.
# Run from the poetry-ui root:
#   bundle exec ruby eval/results/2026-07-09-rebaseline/results_depth5.rb
require "json"

RUN = File.join(Dir.pwd, "eval/results/2026-07-09-rebaseline")

def load_json(name) = JSON.parse(File.read(File.join(RUN, name)))

depth3 = load_json("benchmark-verdicts.json")["tasks"]
depth5_payload = load_json("benchmark-verdicts-depth5.json")
depth5 = depth5_payload["tasks"]

tasks = depth3.keys.sort
changes = tasks.filter_map do |task|
  from = depth3[task]["verdict"]
  to = depth5.dig(task, "verdict")
  [task, "#{from} -> #{to}"] if from != to
end.to_h
identical = tasks.size - changes.size
arm_names = %w[poetry raw_tailwind]
arm_flips = changes.select do |_task, change|
  arm_names.all? { |arm| change.include?(arm) }
end

tally = tasks.map { |task| depth5.dig(task, "verdict") }.tally
swap_mean = (tasks.sum { |task| depth5.dig(task, "swap_consistency").to_f } / tasks.size).round(3)
error_pairs = tasks.select { |task| depth5.dig(task, "verdict").to_s.start_with?("error") }
usage = depth5_payload.dig("summary", "usage") || {}

drifters = {
  "form_controls" => depth5.dig("form_controls", "verdict"),
  "form_field" => depth5.dig("form_field", "verdict"),
  "primitives" => depth5.dig("primitives", "verdict")
}
coin_flips_decided = %w[form_field primitives].count { |task| drifters[task] != "inconclusive" }

predictions = {
  "d1" => { "statement" => ">= 27 of 31 verdicts identical to depth-3",
            "observed" => "#{identical}/31 identical; changes: #{changes.inspect}",
            "pass" => identical >= 27 },
  "d2" => { "statement" => "zero poetry<->raw arm flips between depths",
            "observed" => arm_flips.empty? ? "none" : arm_flips.inspect,
            "pass" => arm_flips.empty? },
  "d3" => { "statement" => "form_controls stays inconclusive; at most one of form_field/primitives decides",
            "observed" => drifters.inspect,
            "pass" => drifters["form_controls"] == "inconclusive" && coin_flips_decided <= 1 },
  "d4" => { "statement" => "~310 calls <= $55; mean swap >= 0.90; zero pairs lost",
            "observed" => "calls #{usage["judge_calls"]}, $#{usage["total_cost_usd"]}, " \
                          "swap #{swap_mean}, error pairs #{error_pairs.inspect}",
            "pass" => usage["total_cost_usd"].to_f <= 55 && swap_mean >= 0.90 && error_pairs.empty? }
}

d1_holds = predictions["d1"]["pass"] && predictions["d2"]["pass"]
decision = if d1_holds
             "depth-3 headline STANDS as canonical (raw 16 - poetry 12 - inc 3) with depth-5 " \
               "confirmation; votes_per_order stays 3 for future runs"
           else
             "depth-5 tally SUPERSEDES as the standing headline; POETRY_JUDGE_VOTES=5 becomes " \
               "the default for future benchmark runs"
           end

payload = {
  "assembled_from" => ["benchmark-verdicts.json (depth 3, canonical)",
                       "benchmark-verdicts-depth5.json (this re-judge)"],
  "usage_note" => "the first 27 pairs' spend is ESTIMATED (270 calls at the re-baseline $0.1333/call " \
                  "rate): the run was externally killed and its in-memory receipts were lost; " \
                  "only the 4-pair resume is receipted exactly",
  "depth5_tally" => tally,
  "verdict_changes_depth3_to_depth5" => changes,
  "arm_flips" => arm_flips,
  "swap_consistency_mean" => swap_mean,
  "usage" => usage,
  "predictions" => predictions,
  "grade" => "#{predictions.count { |_key, p| p["pass"] }}/4 pre-registered predictions pass",
  "decision_rule_outcome" => decision
}

path = File.join(RUN, "results-depth5-grade.json")
File.write(path, JSON.pretty_generate(payload))
puts JSON.pretty_generate(predictions)
puts "depth-5 tally: #{tally.inspect}"
puts "grade: #{payload["grade"]}"
puts "decision: #{decision}"
puts "written: #{path}"
