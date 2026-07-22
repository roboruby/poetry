# frozen_string_literal: true

# Overlay-family arms are authored closed behind their triggers (the honest
# resting DOM), so a naive screenshot shows a lone button. One representative
# reveal interaction per task - run IDENTICALLY on both arms (the judge-
# evidence honesty rule): click the trigger, screenshot whatever results.
# An arm whose trigger does nothing captures that truth. Values are candidate
# trigger texts tried in order (both arms' spellings).
# Verdict classes that are not decisions (excluded from the decided-only
# calibration rate).
POETRY_JUDGE_UNDECIDED = %w[inconclusive error].freeze

# Candidates carry every arm's actual spelling, tried in order - frozen
# arms match their original entries first (committed captures untouched);
# the tail entries are the W2 generated arms' spellings (N15).
POETRY_EVAL_REVEAL = {
  "dialog" => ["Settings"],
  "overlay" => ["Delete API key", "Delete"],
  "mobile_sheet" => ["Set goal", "Set daily goal"],
  "menu" => %w[Options File],
  "searchable_select" => ["Select framework", "Select a framework", "Filter frameworks", "Next.js"],
  "site_nav" => ["Products"],
  "date_field" => ["June 12, 2026", "Pick a date", "Pick a due date", "Jul 15, 2026", "July 14, 2026"],
  "floating" => ["Open popover"]
}.freeze

# Tags preferred on text-length ties when picking the reveal trigger.
POETRY_EVAL_INTERACTIVE_TAGS = %w[button summary a].freeze

# The innermost visible element carrying the trigger text: matches include
# every wrapper whose text contains the needle, so take the shortest text
# (most specific), preferring real interactive tags on ties. Falls back to
# input values (a raw arm's readonly-input trigger). Matching is
# case-insensitive (N15 W2): generated arms spell their triggers freely
# ("Open settings" vs the table's "Settings"); the frozen captures stay
# byte-identical under this widening - verified at the change.
def poetry_ui_eval_reveal_target(session, candidates)
  candidates.each do |needle|
    pattern = Regexp.new(Regexp.escape(needle), Regexp::IGNORECASE)
    matches = session.all("button, summary, a, [role=button], [onclick], span, div",
                          text: pattern, visible: true, wait: 2)
    if matches.any?
      return matches.min_by { |el| [el.text.length, POETRY_EVAL_INTERACTIVE_TAGS.index(el.tag_name) || 9] }
    end

    input = session.all("input", visible: true, wait: 0).find { |el| el.value.to_s.match?(pattern) }
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

# Screenshot every arm the runner can see into captures_root - shared by
# the frozen capture task and the benchmark's generated-arm capture (which
# points the runner and the arms endpoint at a results/<date>/generated
# corpus). Tasks with no arms present (a subset benchmark state) are
# skipped, not errors.
def poetry_ui_eval_capture_all(runner, captures_root, tolerant: false, only: nil)
  require "fileutils"

  session = poetry_ui_browser_session
  count = 0
  # The runner's OWN task set (: the page-scale companion gate's
  # tasks are not Runner::TASKS).
  runner.tasks.keys.sort.each do |task|
    arms = runner.arms(task)
    arms = arms.slice(*only) if only
    next if arms.empty?

    dir = captures_root.join(task)
    FileUtils.mkdir_p(dir)
    arms.keys.sort.each do |arm|
      begin
        poetry_ui_visit_preview(session, "/eval/#{task}/#{arm}")
        poetry_ui_eval_reveal(session, task)
      rescue StandardError => e
        # A GENERATED arm may 500 at render (a real authoring failure) -
        # the error state IS the judge's honest evidence, so screenshot it
        # (tolerant mode, benchmark only). Frozen arms stay loud.
        raise unless tolerant

        puts "  (#{task}/#{arm}: page errored - #{e.class} - capturing the error state)"
      end
      session.driver.save_screenshot(dir.join("#{arm}.png").to_s, full: true)
      count += 1
    end
  end
  count
end

# The judge worker pool (shared by eval:judge and eval:benchmark:judge):
# pull tasks off a queue, stage blind pairs from captures_root, judge, and
# persist every finished task to the partial file (crash insurance). Task
# failures become error-verdict records - the blast-radius rule.
def poetry_ui_eval_judge_run(names:, card:, captures_root:, judge:, partial:)
  queue = Queue.new
  names.each { |task| queue << task }
  results = {}
  mutex = Mutex.new

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
          png = captures_root.join(task, "#{arm}.png")
          abort "missing capture #{png} - run the capture task first" unless png.exist?

          [arm, { "capture" => png.to_s, "ledger" => spec["arms"][arm]["cross_arm"] }]
        end
        record = begin
          judge.judge_pair(task: task, brief: spec["description"], arms: arms)
        rescue Poetry::Eval::Judge::Error => e
          # A task-level failure is a reported verdict class, not a run
          # killer (the blast-radius lesson: call ~180 of 186 once raised
          # and took the whole run's verdicts with it).
          { "brief" => spec["description"], "arms" => arms.keys, "votes" => [],
            "verdict" => "error", "surviving_votes" => 0, "swap_consistency" => 0.0,
            "malformed_votes" => 0, "error" => e.message }
        end
        mutex.synchronize do
          results[task] = record
          Poetry::Ui.root.join(partial).write(JSON.pretty_generate(results.sort.to_h))
          puts format("  %<task>-19s %<verdict>-14s swap-consistency %<swap>.2f",
                      task: task, verdict: record["verdict"], swap: record["swap_consistency"])
        end
      end
    end
  end
  workers.each(&:join)
  results
end

namespace :eval do
  desc "Screenshot every frozen eval arm through the browser rig (the golden-baseline " \
       "settings: light, #{POETRY_BROWSER_VIEWPORT.join("x")}) into eval/captures/ - " \
       "the judge's evidence (not in the default gate - needs Chrome)"
  task capture: :"browser:assets" do
    require_relative "../eval/runner"

    count = poetry_ui_eval_capture_all(Poetry::Eval::Runner.new, Poetry::Ui.root.join("eval/captures"))
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
        if result["render_error"]
          # A frozen arm must always render; the rescue that keeps a
          # GENERATED corpus scoreable (N15 W2) must never let a frozen
          # crash sit quiet here.
          failures << "#{task}/#{arm} failed to render: #{result["render_error"]}"
        elsif result.key?("poetry_only_diagnostics")
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

    puts "judging #{names.size} task pairs (model #{judge.model}, " \
         "#{judge.votes_per_order} votes x 2 orders each)..."
    results = poetry_ui_eval_judge_run(
      names: names, card: card, captures_root: Poetry::Ui.root.join("eval/captures"),
      judge: judge, partial: "tmp/eval-judge-partial.json"
    )

    generated_on = ENV.fetch("POETRY_JUDGE_DATE", Date.today.iso8601)
    dir = Poetry::Ui.root.join("eval/results", generated_on)
    dir.mkpath
    path = dir.join("judge-verdicts.json")

    usage = { "judge_calls" => judge.calls, "total_cost_usd" => judge.total_cost_usd.round(4) }
    # A subset run (POETRY_JUDGE_TASKS) MERGES into the same-date file:
    # re-judged tasks replace their records, the rest stand, usage
    # accumulates - a single-task re-run never clobbers a calibration.
    if path.exist?
      previous = JSON.parse(path.read)
      results = previous.fetch("tasks", {}).merge(results)
      before = previous.dig("summary", "usage") || {}
      usage = {
        "judge_calls" => before.fetch("judge_calls", 0) + usage["judge_calls"],
        "total_cost_usd" => (before.fetch("total_cost_usd", 0.0) + usage["total_cost_usd"]).round(4)
      }
    end

    decided = results.reject { |_, record| POETRY_JUDGE_UNDECIDED.include?(record["verdict"]) }
    agreement = decided.count { |_, record| record["verdict"] == "poetry" }
    payload = {
      "schema" => Poetry::Eval::Judge::SCHEMA,
      "generated_on" => generated_on,
      "model" => judge.model,
      "votes_per_order" => judge.votes_per_order,
      "axes" => Poetry::Eval::Judge::AXES,
      "tasks" => results.sort.to_h,
      "summary" => {
        "verdicts" => results.values.group_by { |record| record["verdict"] }.transform_values(&:size),
        "mean_swap_consistency" =>
          (results.values.sum { |record| record["swap_consistency"] } / results.size).round(3),
        "usage" => usage
      },
      "calibration" => {
        "note" => "Frozen arms have known intended winners (the raw arms were authored WITH " \
                  "failure modes): the intended winner is the poetry arm on every task.",
        "intended_winner" => "poetry",
        "agreement_rate" => "#{agreement}/#{results.size}",
        "agreement_rate_decided" => "#{agreement}/#{decided.size}"
      }
    }
    path.write(JSON.pretty_generate(payload))

    puts "verdicts: #{payload["summary"]["verdicts"].map { |verdict, n| "#{verdict} #{n}" }.join(", ")}"
    puts "calibration agreement: #{payload["calibration"]["agreement_rate"]} " \
         "(#{payload["calibration"]["agreement_rate_decided"]} of decided)"
    puts "mean swap-consistency: #{payload["summary"]["mean_swap_consistency"]}"
    puts "usage: #{judge.calls} judge calls this run, $#{payload["summary"]["usage"]["total_cost_usd"]} cumulative"
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

  # --- The generated-arm benchmark (N15 W2 - the thesis test) --------------
  #
  # Protocol pre-registered in the vault plan note. Stages, each idempotent
  # and resumable, all writing under eval/results/<POETRY_BENCH_DATE>/:
  #
  #   hosts     build the twin fixture hosts (token-free)
  #   generate  62 claude CLI agents write the arms  -> generated/, manifest
  #   score     mechanical gate array on generated arms -> generated-scorecard.json
  #   capture   superset-stylesheet screenshots -> captures/
  #   judge     the W1 paired judge -> benchmark-verdicts.json (NEVER
  #             judge-verdicts.json - that file is the frozen calibration)
  #   aggregate fold everything -> results.json (schema results-v1)
  #
  # Env: POETRY_BENCH_DATE, POETRY_BENCH_MODEL, POETRY_BENCH_MAX_TURNS,
  # POETRY_BENCH_HOSTS, POETRY_BENCH_TASKS, POETRY_BENCH_CONCURRENCY,
  # POETRY_BENCH_FORCE=1 (regenerate), plus the POETRY_JUDGE_* family.
  namespace :benchmark do
    desc "Build the twin fixture hosts (A: installed poetry surface; B: raw-Tailwind twin)"
    task :hosts do
      poetry_ui_boot!
      require_relative "../eval/benchmark"

      a, b = Poetry::Eval::Benchmark.new(results_root: poetry_bench_results_root).build_hosts!
      puts "twin hosts built:\n  A #{a}\n  B #{b}"
    end

    desc "Generate every benchmark arm (claude CLI agents in the twin hosts; resumable)"
    task :generate do
      poetry_ui_boot!
      require_relative "../eval/runner"
      require_relative "../eval/benchmark"
      require "json"

      bench = Poetry::Eval::Benchmark.new(results_root: poetry_bench_results_root)
      bench.build_hosts!
      manifest_path = poetry_bench_results_root.join("generation-manifest.json")
      manifest = manifest_path.exist? ? JSON.parse(manifest_path.read) : {}
      manifest["units"] ||= {}
      manifest["config"] = { "model" => bench.model, "max_turns" => bench.max_turns,
                             "guided" => Poetry::Eval::Benchmark.guided?,
                             "toolbelts" => Poetry::Eval::Benchmark.resolved_toolbelts }
      prior_receipted = manifest.dig("usage", "receipted_cost_usd") || 0.0

      units = poetry_bench_task_names.flat_map do |task|
        Poetry::Eval::Benchmark::ARM_HOSTS.keys.map { |arm| [task, arm] }
      end
      # POETRY_BENCH_ARMS=poetry regenerates only the treated arm (the
      # remediation re-run keeps the control arm's pre-registered
      # sample frozen - resampling the control would confound the delta).
      if (arm_filter = ENV.fetch("POETRY_BENCH_ARMS", nil))
        arms = arm_filter.split(",").map(&:strip)
        unknown = arms - Poetry::Eval::Benchmark::ARM_HOSTS.keys
        abort "unknown POETRY_BENCH_ARMS: #{unknown.join(", ")}" unless unknown.empty?
        units = units.select { |_task, arm| arms.include?(arm) }
      end
      unless ENV["POETRY_BENCH_FORCE"] == "1"
        units = units.reject do |task, arm|
          entry = manifest["units"].dig(task, arm)
          # An error entry only has a placeholder artifact - a plain re-run
          # must retry it, not skip it.
          entry && !entry.key?("error") &&
            poetry_bench_results_root.join("generated", task, "#{arm}.html.erb").exist?
        end
      end
      puts "generating #{units.size} units (model #{bench.model}, max-turns #{bench.max_turns}, " \
           "hosts #{bench.hosts_root}, results #{poetry_bench_results_root})..."

      queue = Queue.new
      units.each { |unit| queue << unit }
      mutex = Mutex.new
      workers = Array.new([Integer(ENV.fetch("POETRY_BENCH_CONCURRENCY", "4")), units.size].min) do
        Thread.new do
          loop do
            task, arm = begin
              queue.pop(true)
            rescue ThreadError
              break
            end
            entry = begin
              bench.generate_unit(task: task, arm: arm,
                                  brief: poetry_bench_spec_tasks.fetch(task)["description"])
            rescue Poetry::Eval::Benchmark::HermeticityError
              raise # experiment-invalidating - the join re-raises and kills the run
            rescue Poetry::Eval::Benchmark::Error => e
              { "error" => e.message[0, 300], "artifact" => false }
            end
            mutex.synchronize do
              manifest["units"][task] ||= {}
              manifest["units"][task][arm] = entry
              manifest["usage"] = poetry_bench_manifest_usage(manifest, bench, prior_receipted)
              manifest_path.dirname.mkpath
              manifest_path.write(JSON.pretty_generate(manifest))
              status = if entry["error"]
                         "ERROR #{entry["error"][0, 60]}"
                       else
                         format("$%<cost>.2f  %<turns>2d turns  %<dur>4.0fs",
                                cost: entry["cost_usd"], turns: entry["num_turns"].to_i,
                                dur: entry["duration_s"])
                       end
              puts format("  %<task>-19s %<arm>-13s %<status>s", task: task, arm: arm, status: status)
            end
          end
        end
      end
      workers.each(&:join)

      usage = manifest["usage"] || {}
      puts "generation: #{usage["units_recorded"]} units recorded, " \
           "$#{usage["unit_cost_sum_usd"]} unit-sum, $#{usage["receipted_cost_usd"]} receipted; " \
           "manifest: #{manifest_path}"
    end

    desc "Run the mechanical gate array over the generated arms -> generated-scorecard.json"
    task :score do
      poetry_ui_boot!
      require_relative "../eval/runner"
      require "json"

      card = Poetry::Eval::Runner.new(arms_root: poetry_bench_results_root.join("generated"),
                                      tasks: poetry_bench_spec_tasks)
                                 .scorecard(fold_judged: false)
      card["generated_note"] = "GENERATED arms (N15 W2 benchmark run), deterministic gates. " \
                               "cross_arm gates are the only comparable numbers; poetry_only " \
                               "gates are diagnostics."
      path = poetry_bench_results_root.join("generated-scorecard.json")
      path.write(JSON.pretty_generate(card))
      card["tasks"].each do |task, spec|
        next if spec["arms"].empty?

        scores = spec["arms"].sort.map do |arm, result|
          note = result["render_error"] ? " (render error)" : ""
          "#{arm} #{result["cross_arm_score"]}#{note}"
        end
        puts format("  %<task>-19s %<scores>s", task: task, scores: scores.join("  "))
      end
      puts "generated scorecard: #{path}"
    end

    desc "Screenshot the generated arms (superset stylesheet - no purge bias) -> captures/"
    task capture: :"browser:assets" do
      require_relative "../eval/runner"

      generated = poetry_bench_results_root.join("generated")
      abort "no generated arms at #{generated} - run eval:benchmark:generate first" unless generated.exist?

      # Recompile the capture stylesheet WITH the generated arms as a
      # Tailwind source: a raw arm's arbitrary utilities must render with
      # full fidelity or the judge's evidence is purge-biased.
      File.write(poetry_ui_dummy_assets_dir.join("poetry.css"),
                 poetry_ui_compile_tailwind(extra_sources: [generated]))
      ENV["POETRY_EVAL_ARMS_ROOT"] = generated.to_s
      count = poetry_ui_eval_capture_all(
        Poetry::Eval::Runner.new(arms_root: generated, tasks: poetry_bench_spec_tasks),
        poetry_bench_results_root.join("captures"), tolerant: true
      )
      puts "benchmark capture: #{count} screenshots in #{poetry_bench_results_root.join("captures")}"
    end

    desc "Theme-variant recapture: poetry arms under POETRY_BENCH_THEME, raw PNGs reused byte-for-byte"
    task capture_themed: :"browser:assets" do
      require_relative "../eval/runner"
      require "fileutils"

      # The theme sensitivity pass: SAME generated markup (poetry
      # components are theme-agnostic by construction - cn-* names resolve
      # through the theme layer), recaptured under a shipped rich theme.
      # The raw arm's evidence is reused from the source run untouched: raw
      # utilities restate their colors inline and must not shift under a
      # theme's base layer, so the judge compares themed poetry against the
      # exact raw pixels the pre-registered run judged.
      theme = ENV.fetch("POETRY_BENCH_THEME", "vega")
      source = Pathname(ENV.fetch("POETRY_BENCH_SOURCE"))
      generated = source.join("generated")
      abort "no generated arms at #{generated}" unless generated.exist?

      captures = poetry_bench_results_root.join(ENV.fetch("POETRY_BENCH_CAPTURES_DIR", "captures-themed-#{theme}"))
      File.write(poetry_ui_dummy_assets_dir.join("poetry.css"),
                 poetry_ui_compile_tailwind(theme: theme, extra_sources: [generated]))
      ENV["POETRY_EVAL_ARMS_ROOT"] = generated.to_s
      count = poetry_ui_eval_capture_all(Poetry::Eval::Runner.new(arms_root: generated), captures,
                                         tolerant: true, only: ["poetry"])
      copied = Dir.glob(source.join("captures/*/raw_tailwind.png").to_s).sum do |png|
        task_dir = captures.join(File.basename(File.dirname(png)))
        FileUtils.mkdir_p(task_dir)
        FileUtils.cp(png, task_dir.join("raw_tailwind.png"))
        1
      end
      puts "themed capture (#{theme}): #{count} poetry screenshots + #{copied} raw reused in #{captures}"
    end

    desc "Judge the generated pairs (the W1 paired judge) -> benchmark-verdicts.json"
    task :judge do
      poetry_ui_boot!
      require_relative "../eval/runner"
      require_relative "../eval/judge"
      require_relative "../eval/benchmark"
      require "json"
      require "date"
      require "tmpdir"

      # Variant runs point SOURCE at the arms/captures to judge and
      # VERDICTS at their own output file - the default remains this run's
      # own dir end-to-end.
      source = Pathname(ENV.fetch("POETRY_BENCH_SOURCE", poetry_bench_results_root.to_s))
      generated = source.join("generated")
      captures = poetry_bench_results_root.join(ENV.fetch("POETRY_BENCH_CAPTURES_DIR", "captures"))
      card = Poetry::Eval::Runner.new(arms_root: generated, tasks: poetry_bench_spec_tasks)
                                 .scorecard(fold_judged: false)
      # POETRY_JUDGE_VOTES deepens the anti-bias harness (: votes per
      # presentation order; the default 3 = 6 calls/pair, 5 = 10). Pair a
      # non-default depth with POETRY_BENCH_VERDICTS so the canonical
      # verdicts file stays frozen.
      judge = Poetry::Eval::Judge.new(
        workdir: File.join(Dir.tmpdir, "ui-eval-bench-judge"),
        votes_per_order: Integer(ENV.fetch("POETRY_JUDGE_VOTES", Poetry::Eval::Judge::VOTES_PER_ORDER))
      )

      names = poetry_bench_task_names.select do |task|
        card["tasks"].fetch(task)["arms"].size == 2 &&
          Poetry::Eval::Benchmark::ARM_HOSTS.keys.all? { |arm| captures.join(task, "#{arm}.png").exist? }
      end
      skipped = poetry_bench_task_names - names
      puts "skipping #{skipped.size} tasks without complete pairs+captures: #{skipped.join(", ")}" if skipped.any?

      path = poetry_bench_results_root.join(ENV.fetch("POETRY_BENCH_VERDICTS", "benchmark-verdicts.json"))
      puts "judging #{names.size} generated pairs (model #{judge.model}, " \
           "#{judge.votes_per_order} votes x 2 orders each) -> #{path.basename}..."
      results = poetry_ui_eval_judge_run(
        names: names, card: card, captures_root: captures,
        judge: judge, partial: "tmp/eval-bench-judge-partial-#{path.basename(".json")}.json"
      )
      usage = { "judge_calls" => judge.calls, "total_cost_usd" => judge.total_cost_usd.round(4) }
      if path.exist?
        previous = JSON.parse(path.read)
        results = previous.fetch("tasks", {}).merge(results)
        before = previous.dig("summary", "usage") || {}
        usage = {
          "judge_calls" => before.fetch("judge_calls", 0) + usage["judge_calls"],
          "total_cost_usd" => (before.fetch("total_cost_usd", 0.0) + usage["total_cost_usd"]).round(4)
        }
      end

      payload = {
        "schema" => Poetry::Eval::Judge::SCHEMA,
        "context" => "generated-arm benchmark (N15 W2) - agent output, unknown intended winner; " \
                     "no calibration key by design (the frozen-arm judge-verdicts.json carries it)",
        "generated_on" => ENV.fetch("POETRY_BENCH_DATE", Date.today.iso8601),
        "model" => judge.model,
        "votes_per_order" => judge.votes_per_order,
        "axes" => Poetry::Eval::Judge::AXES,
        "tasks" => results.sort.to_h,
        "summary" => {
          "verdicts" => results.values.group_by { |record| record["verdict"] }.transform_values(&:size),
          "mean_swap_consistency" =>
            (results.values.sum { |record| record["swap_consistency"] } / results.size).round(3),
          "usage" => usage
        }
      }
      path.write(JSON.pretty_generate(payload))

      puts "verdicts: #{payload["summary"]["verdicts"].map { |verdict, n| "#{verdict} #{n}" }.join(", ")}"
      puts "mean swap-consistency: #{payload["summary"]["mean_swap_consistency"]}"
      puts "usage: #{judge.calls} judge calls this run, $#{usage["total_cost_usd"]} cumulative"
      puts "verdicts written: #{path}"
    end

    desc "Fold generation + gates + verdicts into results.json (schema results-v1)"
    task :aggregate do
      poetry_ui_boot!
      require_relative "../eval/benchmark"
      require "json"
      require "date"

      root = poetry_bench_results_root
      # Variant folds (vote-depth re-judge): POETRY_BENCH_VERDICTS
      # names the verdicts input and POETRY_BENCH_RESULTS the output, so a
      # re-judge aggregates alongside the canonical results.json, never
      # over it.
      verdicts_path = root.join(ENV.fetch("POETRY_BENCH_VERDICTS", "benchmark-verdicts.json"))
      payload = Poetry::Eval::Benchmark.aggregate(
        scorecard: JSON.parse(root.join("generated-scorecard.json").read),
        verdicts: JSON.parse(verdicts_path.read),
        manifest: JSON.parse(root.join("generation-manifest.json").read),
        meta: {
          "generated_on" => ENV.fetch("POETRY_BENCH_DATE", Date.today.iso8601),
          "generation" => JSON.parse(root.join("generation-manifest.json").read)
                              .values_at("config", "usage").compact.reduce(:merge),
          "protocol_notes" => [
            "hermetic generation: claude CLI cwd'd into twin tmp hosts; host B tree+prompt " \
            "asserted free of the house name (HermeticityError aborts the run)",
            "one identical generation prompt for both arms; the treatment lives in host files",
            "symmetric no-<script> rule; native HTML capabilities allowed on both arms",
            "capture stylesheet compiled with the generated arms as a Tailwind source (no purge bias)"
          ]
        }
      )
      path = root.join(ENV.fetch("POETRY_BENCH_RESULTS", "results.json"))
      path.write(JSON.pretty_generate(payload))

      summary = payload["summary"]
      puts "benchmark: #{summary["overall"].map { |verdict, n| "#{verdict} #{n}" }.join(", ")} " \
           "(#{payload["tasks"].size} pairs; incomplete: #{payload["incomplete"].size})"
      win = summary["win_rate"]
      puts "win rate: headline #{win["poetry_headline"]["n"]}/#{win["poetry_headline"]["of"]}, " \
           "decided #{win["poetry_decided"]["n"]}/#{win["poetry_decided"]["of"]}"
      summary["axes"].each do |axis, tally|
        puts format("  axis %<axis>-12s %<tally>s", axis: axis,
                                                    tally: tally.map { |winner, n| "#{winner} #{n}" }.join(", "))
      end
      payload["predictions"].each do |key, record|
        outcome = record.key?("held") ? "held: #{record["held"]}" : "triggered: #{record["triggered"]}"
        puts "#{key}: #{outcome}"
      end
      puts "results: #{path}"
    end

    desc "The full benchmark pipeline: generate -> score -> capture -> judge -> aggregate"
    task run: %i[generate score capture judge aggregate]
  end

  # Degradation mode: multi-turn convention-survival over the
  # pre-registered 10-brief sample. The generate stage is its own driver
  # (conversation chains + probes); every downstream stage is the UNCHANGED
  # eval:benchmark machinery pointed at the probe dirs (they are
  # benchmark-run shaped on purpose). Root: eval/results/<date>-degradation
  # with p0/p1/p2 probe runs inside.
  namespace :degradation do
    desc "Run the 10-brief x 2-arm degradation conversations -> probe dirs + degradation-manifest.json"
    task :generate do
      poetry_ui_boot!
      require_relative "../eval/degradation"
      require "json"

      deg = Poetry::Eval::Degradation.new(results_root: poetry_degradation_root)
      deg.build_hosts!
      manifest_path = poetry_degradation_root.join("degradation-manifest.json")
      manifest = manifest_path.exist? ? JSON.parse(manifest_path.read) : {}
      manifest["units"] ||= {}
      manifest["config"] = {
        "model" => deg.model, "sample" => Poetry::Eval::Degradation::SAMPLE,
        "budgets" => Poetry::Eval::Degradation::BUDGETS,
        "sequence" => Poetry::Eval::Degradation::SEQUENCE.map { |step| step.compact.join(":") },
        "toolbelts" => Poetry::Eval::Degradation::TOOLBELTS
      }
      prior_receipted = manifest.dig("usage", "receipted_cost_usd") || 0.0

      # POETRY_BENCH_TASKS chunks the run (the lesson: long
      # CLI-spawning rakes die to SIGTERM in the background - foreground
      # chunks are the kill-proof procedure; the manifest resumes exactly).
      sample = Poetry::Eval::Degradation::SAMPLE
      if (filter = ENV.fetch("POETRY_BENCH_TASKS", nil))
        names = filter.split(",").map(&:strip)
        unknown = names - sample
        abort "unknown POETRY_BENCH_TASKS: #{unknown.join(", ")}" unless unknown.empty?
        sample = names
      end
      units = sample.flat_map do |task|
        Poetry::Eval::Degradation::ARM_HOSTS.keys.map { |arm| [task, arm] }
      end
      unless ENV["POETRY_BENCH_FORCE"] == "1"
        units = units.reject do |task, arm|
          entry = manifest["units"].dig(task, arm)
          entry && !entry.key?("error") &&
            Poetry::Eval::Degradation::PROBES.all? do |probe|
              poetry_degradation_root.join(probe, "generated", task, "#{arm}.html.erb").exist?
            end
        end
      end
      puts "degradation: #{units.size} conversations (model #{deg.model}, " \
           "#{Poetry::Eval::Degradation::SEQUENCE.count { |step, _k, _i| step == :message }} messages each) " \
           "-> #{poetry_degradation_root}..."

      queue = Queue.new
      units.each { |unit| queue << unit }
      mutex = Mutex.new
      workers = Array.new([Integer(ENV.fetch("POETRY_BENCH_CONCURRENCY", "4")), units.size].min) do
        Thread.new do
          loop do
            task_name, arm = begin
              queue.pop(true)
            rescue ThreadError
              break
            end
            entry = begin
              deg.degrade_unit(task: task_name, arm: arm,
                               brief: Poetry::Eval::Runner::TASKS.fetch(task_name)["description"])
            rescue Poetry::Eval::Benchmark::HermeticityError
              raise
            rescue Poetry::Eval::Benchmark::Error => e
              { "error" => e.message[0, 300] }
            end
            mutex.synchronize do
              manifest["units"][task_name] ||= {}
              manifest["units"][task_name][arm] = entry
              manifest["usage"] = poetry_degradation_usage(manifest, deg, prior_receipted)
              manifest_path.dirname.mkpath
              manifest_path.write(JSON.pretty_generate(manifest))
              status = if entry["error"]
                         "ERROR #{entry["error"][0, 60]}"
                       else
                         cost = entry["messages"].sum { |message| message["cost_usd"].to_f }
                         format("$%<cost>.2f  probes %<probes>s", cost: cost,
                                                                  probes: entry["probes"].values.join("/"))
                       end
              puts format("  %<task>-19s %<arm>-13s %<status>s", task: task_name, arm: arm, status: status)
            end
          end
        end
      end
      workers.each(&:join)
      puts "degradation manifest: #{manifest_path} ($#{manifest.dig("usage", "receipted_cost_usd")} receipted)"
    end

    desc "Score all three probes through the benchmark score stage"
    task :score do
      require_relative "../eval/degradation"
      poetry_degradation_stage("score", Poetry::Eval::Degradation::PROBES)
    end

    desc "Capture the judged probes (p0, p2) through the benchmark capture stage"
    task :capture do
      require_relative "../eval/degradation"
      poetry_degradation_stage("capture", Poetry::Eval::Degradation::JUDGED_PROBES)
    end

    desc "Judge the p0 and p2 pairs through the benchmark judge stage"
    task :judge do
      require_relative "../eval/degradation"
      poetry_degradation_stage("judge", Poetry::Eval::Degradation::JUDGED_PROBES)
    end

    desc "Fold probes + verdicts + manifest into degradation-results.json (schema degradation-v1)"
    task :aggregate do
      poetry_ui_boot!
      require_relative "../eval/degradation"
      require "json"
      require "date"

      root = poetry_degradation_root
      scorecards = Poetry::Eval::Degradation::PROBES.to_h do |probe|
        [probe, JSON.parse(root.join(probe, "generated-scorecard.json").read)]
      end
      verdicts = Poetry::Eval::Degradation::JUDGED_PROBES.to_h do |probe|
        [probe, JSON.parse(root.join(probe, "benchmark-verdicts.json").read)]
      end
      artifacts = Poetry::Eval::Degradation::PROBES.to_h do |probe|
        [probe, Poetry::Eval::Degradation::SAMPLE.to_h do |task|
          [task, Poetry::Eval::Degradation::ARM_HOSTS.keys.to_h do |arm|
            path = root.join(probe, "generated", task, "#{arm}.html.erb")
            [arm, path.exist? ? path.read : ""]
          end]
        end]
      end
      payload = Poetry::Eval::Degradation.aggregate(
        scorecards: scorecards, verdicts: verdicts, artifacts: artifacts,
        manifest: JSON.parse(root.join("degradation-manifest.json").read),
        meta: {
          "generated_on" => ENV.fetch("POETRY_BENCH_DATE", Date.today.iso8601),
          "protocol_notes" => [
            "multi-turn continuation via claude -p --resume (session chain per unit)",
            "probes p0/p1/p2 at the pre-registered depths; p1 mechanical-only",
            "fillers are chat-only by instruction; the distractor is a temptation, never an order",
            "budget exhaustion on a follow-up is recorded data, never a unit error"
          ]
        }
      )
      path = root.join("degradation-results.json")
      path.write(JSON.pretty_generate(payload))
      summary = payload["summary"]
      puts "pass rates: #{summary["probe_pass_rates"].map do |arm, rates|
        "#{arm} #{rates.values.join(" -> ")}"
      end.join("  |  ")}"
      puts "drop p0->p2: #{summary["drop_p0_to_p2"].map { |arm, drop| "#{arm} #{drop}" }.join(", ")}"
      puts "judged poetry wins: #{summary["judged_poetry_wins"].map { |probe, n| "#{probe} #{n}" }.join(", ")}"
      summary["predictions"].each do |key, record|
        puts "#{key}: #{record["pass"] ? "PASS" : "FAIL"} - #{record["detail"]}"
      end
      puts "results: #{path}"
    end

    desc "The full degradation pipeline: generate -> score -> capture -> judge -> aggregate"
    task run: %i[generate score capture judge aggregate]
  end
end

# Shared roots/filters for the eval:benchmark:* stages.
def poetry_bench_results_root
  require "date"
  Poetry::Ui.root.join("eval/results", ENV.fetch("POETRY_BENCH_DATE", Date.today.iso8601))
end

# The benchmark's task-spec source: the standing 31-brief set by
# default; POETRY_BENCH_SPEC=pagescale runs the page-scale companion gate
# through the identical machinery. The companion gate NEVER replaces the
# standing headline (pre-registered, permanent).
def poetry_bench_spec_tasks
  case (spec = ENV.fetch("POETRY_BENCH_SPEC", "standing"))
  when "standing" then Poetry::Eval::Runner::TASKS
  when "pagescale", "guided"
    # pagescale = the page-scale briefs. "guided" reuses the
    # SAME briefs - composition is the page-scale axis - and puts the
    # treatment in the toolbelt instead: POETRY_BENCH_GUIDED=1 adds build_page
    # to the poetry belt (control vs treatment). Protocol + pre-registered
    # predictions: eval/guided.md.
    require_relative "../eval/pagescale"
    Poetry::Eval::Pagescale::TASKS
  when "holdout"
    # The holdout stratum: run ONLY to validate an agent-surface
    # change, never to tune one (doctrine in eval/holdout.rb).
    require_relative "../eval/holdout"
    Poetry::Eval::Holdout::TASKS
  else
    abort "unknown POETRY_BENCH_SPEC #{spec.inspect} (standing | pagescale | holdout | guided)"
  end
end

def poetry_bench_task_names
  tasks = poetry_bench_spec_tasks
  names = tasks.keys.sort
  if (filter = ENV.fetch("POETRY_BENCH_TASKS", nil))
    names = filter.split(",").map(&:strip)
    unknown = names - tasks.keys
    abort "unknown POETRY_BENCH_TASKS: #{unknown.join(", ")}" unless unknown.empty?
  end
  names
end

# Manifest usage totals: the comparable per-unit sum plus the receipted
# total (which includes retried attempts' spend, accumulated across
# resumed runs).
def poetry_bench_manifest_usage(manifest, bench, prior_receipted)
  entries = manifest["units"].values.flat_map(&:values)
  {
    "units_recorded" => entries.size,
    "unit_cost_sum_usd" => entries.sum { |entry| entry["cost_usd"].to_f }.round(4),
    "receipted_cost_usd" => (prior_receipted + bench.receipted_cost_usd).round(4)
  }
end

# The degradation run's own root: eval/results/<date>-degradation, with the
# p0/p1/p2 probe runs nested inside. POETRY_DEG_DATE (not POETRY_BENCH_DATE:
# the probe stages rewrite that per probe) pins a specific run.
def poetry_degradation_root
  require "date"
  Poetry::Ui.root.join("eval/results", "#{ENV.fetch("POETRY_DEG_DATE", Date.today.iso8601)}-degradation")
end

def poetry_degradation_usage(manifest, deg, prior_receipted)
  entries = manifest["units"].values.flat_map(&:values)
  {
    "units_recorded" => entries.size,
    "unit_cost_sum_usd" => entries.sum do |entry|
      (entry["messages"] || []).sum { |message| message["cost_usd"].to_f }
    end.round(4),
    "receipted_cost_usd" => (prior_receipted + deg.receipted_cost_usd).round(4)
  }
end

# Run one UNCHANGED eval:benchmark stage once per probe dir: the probe
# dirs are benchmark-run shaped exactly so these stages need no variants.
def poetry_degradation_stage(stage, probes)
  poetry_ui_boot!
  require_relative "../eval/degradation"
  prefix = poetry_degradation_root.basename.to_s
  probes.each do |probe|
    ENV["POETRY_BENCH_DATE"] = "#{prefix}/#{probe}"
    ENV["POETRY_BENCH_TASKS"] = Poetry::Eval::Degradation::SAMPLE.join(",")
    puts "== degradation #{stage} @ #{probe} =="
    stage_task = Rake::Task["eval:benchmark:#{stage}"]
    stage_task.reenable
    stage_task.invoke
  ensure
    ENV.delete("POETRY_BENCH_DATE")
    ENV.delete("POETRY_BENCH_TASKS")
  end
end
