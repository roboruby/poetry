# frozen_string_literal: true

# Overlay-family arms are authored closed behind their triggers (the honest
# resting DOM), so a naive screenshot shows a lone button. One representative
# reveal interaction per task - run IDENTICALLY on both arms (the judge-
# evidence honesty rule): click the trigger, screenshot whatever results.
# An arm whose trigger does nothing captures that truth. Values are candidate
# trigger texts tried in order (both arms' spellings).
POETRY_EVAL_REVEAL = {
  "dialog" => ["Settings"],
  "overlay" => ["Delete API key"],
  "mobile_sheet" => ["Set goal"],
  "menu" => ["Options"],
  "searchable_select" => ["Select framework", "Next.js"],
  "site_nav" => ["Products"],
  "date_field" => ["June 12, 2026", "Pick a date"],
  "floating" => ["Open popover"]
}.freeze

# Tags preferred on text-length ties when picking the reveal trigger.
POETRY_EVAL_INTERACTIVE_TAGS = %w[button summary a].freeze

# The innermost visible element carrying the trigger text: matches include
# every wrapper whose text contains the needle, so take the shortest text
# (most specific), preferring real interactive tags on ties. Falls back to
# input values (a raw arm's readonly-input trigger).
def poetry_ui_eval_reveal_target(session, candidates)
  candidates.each do |needle|
    matches = session.all("button, summary, a, [role=button], [onclick], span, div",
                          text: needle, visible: true, wait: 2)
    if matches.any?
      return matches.min_by { |el| [el.text.length, POETRY_EVAL_INTERACTIVE_TAGS.index(el.tag_name) || 9] }
    end

    input = session.all("input", visible: true, wait: 0).find { |el| el.value.to_s.include?(needle) }
    return input if input
  end
  nil
end

def poetry_ui_eval_reveal(session, task)
  candidates = POETRY_EVAL_REVEAL[task]
  return if candidates.nil?

  target = poetry_ui_eval_reveal_target(session, candidates)
  if target.nil?
    puts "  (#{task}: no visible trigger matching #{candidates.inspect} - captured at rest)"
    return
  end
  begin
    target.click
    sleep 0.5 # floating-ui positioning settles; reduced-motion killed the animations
  rescue StandardError => e
    puts "  (#{task}: reveal click failed - #{e.class}: #{e.message} - captured at rest)"
  end
end

namespace :eval do
  desc "Screenshot every frozen eval arm through the browser rig (the golden-baseline " \
       "settings: light, #{POETRY_BROWSER_VIEWPORT.join("x")}) into eval/captures/ - " \
       "the judge's evidence (not in the default gate - needs Chrome)"
  task capture: :"browser:assets" do
    require_relative "../eval/runner"
    require "fileutils"

    session = poetry_ui_browser_session
    runner = Poetry::Eval::Runner.new
    count = 0

    Poetry::Eval::Runner::TASKS.keys.sort.each do |task|
      dir = Poetry::Ui.root.join("eval/captures", task)
      FileUtils.mkdir_p(dir)
      runner.arms(task).keys.sort.each do |arm|
        poetry_ui_visit_preview(session, "/eval/#{task}/#{arm}")
        poetry_ui_eval_reveal(session, task)
        session.driver.save_screenshot(dir.join("#{arm}.png").to_s, full: true)
        count += 1
      end
    end
    puts "eval capture: #{count} screenshots in eval/captures/ " \
         "(#{Poetry::Eval::Runner::TASKS.size} tasks, viewport #{POETRY_BROWSER_VIEWPORT.join("x")})"
  end

  desc "The eval regression net (deterministic - in the default gate): every poetry arm passes " \
       "every cross-arm gate and every diagnostic; every raw arm still fails at least one " \
       "cross-arm gate, so the planted tells survive gate evolution"
  task :verify do
    poetry_ui_boot!
    require_relative "../eval/runner"

    card = Poetry::Eval::Runner.new.scorecard
    failures = []
    card["tasks"].each do |task, spec|
      spec["arms"].each do |arm, result|
        if result.key?("poetry_only_diagnostics")
          broken = result["cross_arm"].reject { |_, pass| pass }.keys +
                   result["poetry_only_diagnostics"].reject { |_, pass| pass }.keys
          failures << "#{task}/#{arm} fails: #{broken.join(", ")}" unless broken.empty?
        elsif result["cross_arm"].values.all?
          failures << "#{task}/#{arm} passes every cross-arm gate - its planted tell is gone " \
                      "(a gate rewrite stopped catching this arm's authored failure modes)"
        end
      end
    end
    abort "eval verify:\n  #{failures.join("\n  ")}" unless failures.empty?

    puts "eval verify: #{card["tasks"].size} task pairs hold (poetry arms fully green, " \
         "every raw arm still carries a tell)"
  end

  desc "Run the paired LLM judge over the frozen eval arms (the claude CLI; needs eval/captures) " \
       "and write eval/results/<date>/judge-verdicts.json. POETRY_JUDGE_TASKS=a,b filters; " \
       "POETRY_JUDGE_MODEL, POETRY_JUDGE_CONCURRENCY, POETRY_JUDGE_DATE tune."
  task :judge do
    poetry_ui_boot!
    require_relative "../eval/runner"
    require_relative "../eval/judge"
    require "json"
    require "date"

    runner = Poetry::Eval::Runner.new
    card = runner.scorecard # fresh mechanical ledgers; only cross_arm reaches the judge
    judge = Poetry::Eval::Judge.new

    names = Poetry::Eval::Runner::TASKS.keys.sort
    if (filter = ENV.fetch("POETRY_JUDGE_TASKS", nil))
      names = filter.split(",").map(&:strip)
      unknown = names - Poetry::Eval::Runner::TASKS.keys
      abort "unknown POETRY_JUDGE_TASKS: #{unknown.join(", ")}" unless unknown.empty?
    end

    queue = Queue.new
    names.each { |task| queue << task }
    results = {}
    mutex = Mutex.new
    puts "judging #{names.size} task pairs (model #{judge.model}, " \
         "#{judge.votes_per_order} votes x 2 orders each)..."

    workers = Array.new([Integer(ENV.fetch("POETRY_JUDGE_CONCURRENCY", "4")), names.size].min) do
      Thread.new do
        loop do
          task = begin
            queue.pop(true)
          rescue ThreadError
            break
          end
          spec = card["tasks"].fetch(task)
          arms = spec["arms"].keys.sort.to_h do |arm|
            png = Poetry::Ui.root.join("eval/captures", task, "#{arm}.png")
            abort "missing capture #{png} - run rake eval:capture first" unless png.exist?

            [arm, { "capture" => png.to_s, "ledger" => spec["arms"][arm]["cross_arm"] }]
          end
          record = judge.judge_pair(task: task, brief: spec["description"], arms: arms)
          mutex.synchronize do
            results[task] = record
            puts format("  %<task>-19s %<verdict>-14s swap-consistency %<swap>.2f",
                        task: task, verdict: record["verdict"], swap: record["swap_consistency"])
          end
        end
      end
    end
    workers.each(&:join)

    decided = results.reject { |_, record| record["verdict"] == "inconclusive" }
    agreement = decided.count { |_, record| record["verdict"] == "poetry" }
    payload = {
      "schema" => Poetry::Eval::Judge::SCHEMA,
      "generated_on" => ENV.fetch("POETRY_JUDGE_DATE", Date.today.iso8601),
      "model" => judge.model,
      "votes_per_order" => judge.votes_per_order,
      "axes" => Poetry::Eval::Judge::AXES,
      "tasks" => results.sort.to_h,
      "summary" => {
        "verdicts" => results.values.group_by { |record| record["verdict"] }.transform_values(&:size),
        "mean_swap_consistency" =>
          (results.values.sum { |record| record["swap_consistency"] } / results.size).round(3),
        "usage" => { "judge_calls" => judge.calls, "total_cost_usd" => judge.total_cost_usd.round(4) }
      },
      "calibration" => {
        "note" => "Frozen arms have known intended winners (the raw arms were authored WITH " \
                  "failure modes): the intended winner is the poetry arm on every task.",
        "intended_winner" => "poetry",
        "agreement_rate" => "#{agreement}/#{results.size}",
        "agreement_rate_decided" => "#{agreement}/#{decided.size}"
      }
    }
    dir = Poetry::Ui.root.join("eval/results", payload["generated_on"])
    dir.mkpath
    path = dir.join("judge-verdicts.json")
    path.write(JSON.pretty_generate(payload))

    puts "verdicts: #{payload["summary"]["verdicts"].map { |verdict, n| "#{verdict} #{n}" }.join(", ")}"
    puts "calibration agreement: #{payload["calibration"]["agreement_rate"]} " \
         "(#{payload["calibration"]["agreement_rate_decided"]} of decided)"
    puts "mean swap-consistency: #{payload["summary"]["mean_swap_consistency"]}"
    puts "usage: #{judge.calls} judge calls, $#{payload["summary"]["usage"]["total_cost_usd"]}"
    puts "verdicts written: #{path}"
  end

  desc "Run the eval harness (frozen task arms, deterministic gates) and emit the scorecard"
  task :scorecard do
    poetry_ui_boot!
    require_relative "../eval/runner"

    card, path = Poetry::Eval::Runner.new.write!
    card["tasks"].each do |task, spec|
      puts "#{task}: #{spec["description"]}"
      spec["arms"].each do |arm, result|
        gates = result["cross_arm"].map { |gate, pass| "#{pass ? "+" : "-"}#{gate}" }.join(" ")
        puts "  #{arm.ljust(14)} cross-arm #{result["cross_arm_score"]}  #{gates}"
        if (diag = result["poetry_only_diagnostics"])
          puts "  #{" ".ljust(14)} diagnostics    #{diag.map { |gate, pass| "#{pass ? "+" : "-"}#{gate}" }.join(" ")}"
        end
      end
    end
    puts "components exercised: #{card["components_exercised"].join(", ")}"
    if (judged = card["judged"])
      tally = judged["verdicts"].values.tally.map { |verdict, n| "#{verdict} #{n}" }.join(", ")
      puts "judged (#{judged["model"]}, #{judged["source"]}): #{tally}; " \
           "calibration agreement #{judged.dig("calibration", "agreement_rate")}"
    end
    puts "scorecard: #{path}"
  end
end
