# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "tmpdir"
require "pathname"

module Poetry
  module Eval
    # The generated-arm benchmark (N15 W2, the thesis test - protocol
    # pre-registered in the vault plan note before the run). Frozen arms
    # measure the system's floor; this measures AGENT OUTPUT: per brief,
    # generation agent A works in a fixture host WITH poetry (the installed
    # agent surface: AGENTS.md section, materialized llms.txt/llms-full.txt,
    # bin/check), agent B in a raw-Tailwind twin - same model, same turn
    # budget, one identical prompt. Both outputs run the full mechanical
    # array, then the W1 paired judge. Results schema: results-v1.
    #
    # Fairness mechanisms (each load-bearing):
    # - Hermetic generation: agents run through the claude CLI cwd'd into a
    #   tmp host OUTSIDE this repo, so the only context is the host's own
    #   files. assert_hermetic! is the runtime guarantee that host B's tree
    #   and the prompt never contain the house name (the assert_blind!
    #   discipline applied to generation).
    # - One prompt, no arm conditionals: the treatment lives entirely in the
    #   host files (AGENTS.md is the app's own voice in both hosts).
    # - Symmetric no-<script> rule: neither agent ships page JS; native HTML
    #   capabilities are allowed. Poetry's wired controllers ARE the
    #   treatment; a raw app's missing JS is the reality the frozen arms
    #   already encode.
    # - No purge bias at capture time: the capture stylesheet compiles with
    #   the generated arms as an extra Tailwind @source, so arbitrary raw
    #   utilities render with full fidelity (rakelib/eval.rake).
    class Benchmark
      SCHEMA = "results-v1"
      UNDECIDED = %w[inconclusive error].freeze
      DEFAULT_MODEL = "claude-sonnet-5"
      DEFAULT_MAX_TURNS = 24
      MAX_GENERATION_ATTEMPTS = 3
      HERMETIC_NEEDLE = "poetry"
      ARM_HOSTS = { "poetry" => "a", "raw_tailwind" => "b" }.freeze
      # The toolbelt asymmetry IS the pre-registered treatment: host A's
      # `poetry check` is runnable (bin/check); host B has nothing to run.
      TOOLBELTS = {
        "poetry" => "Read,Glob,Grep,Write,Bash(bin/check:*)",
        "raw_tailwind" => "Read,Glob,Grep,Write"
      }.freeze
      # CLAUDE.md is byte-identical in both hosts: the project-memory hook
      # the claude CLI auto-loads must not itself be a treatment.
      COMMON_CLAUDE_MD = <<~MD
        Read AGENTS.md for how UI is built in this application before writing any view.
      MD

      class Error < StandardError; end
      # A hermeticity breach invalidates the experiment - it must abort the
      # run, never degrade into a recorded per-unit error.
      class HermeticityError < Error; end

      def initialize(results_root:,
                     model: ENV.fetch("POETRY_BENCH_MODEL", DEFAULT_MODEL),
                     max_turns: Integer(ENV.fetch("POETRY_BENCH_MAX_TURNS", DEFAULT_MAX_TURNS.to_s)),
                     hosts_root: ENV.fetch("POETRY_BENCH_HOSTS", File.join(Dir.tmpdir, "ui-eval-bench-hosts")),
                     ui_root: Poetry::Ui.root)
        @results_root = Pathname(results_root)
        @model = model
        @max_turns = max_turns
        @hosts_root = Pathname(hosts_root)
        @ui_root = Pathname(ui_root)
        @usage_mutex = Mutex.new
        @receipted_cost_usd = 0.0
        @calls = 0
      end

      attr_reader :model, :max_turns, :hosts_root, :results_root, :receipted_cost_usd, :calls

      def host_root(arm)
        @hosts_root.join(ARM_HOSTS.fetch(arm))
      end

      def generated_root
        @results_root.join("generated")
      end

      # ----------------------------------------------------------------- hosts

      # Build (or refresh) the twin fixture hosts. Token-free. Host A gets
      # the real installed agent surface - the canonical AGENTS.md section
      # from the poetry:agents generator, llms.txt/llms-full.txt materialized
      # from the live registry (the exact text the engine's routes serve),
      # and bin/check wrapping `rake poetry:check`. Host B is the twin with
      # the poetry surface absent - and provably absent (assert_hermetic!).
      def build_hosts!
        require "generators/poetry/agents_section"

        ARM_HOSTS.each_key { |arm| FileUtils.mkdir_p(host_root(arm).join("app/views/eval")) }
        write_common_files
        write_host_a
        write_host_b
        self.class.assert_hermetic!(host_root("raw_tailwind"))
        [host_root("poetry"), host_root("raw_tailwind")]
      end

      # ------------------------------------------------------------ generation

      # Generate one arm of one task: a fresh claude CLI agent in the arm's
      # host, the identical prompt, the arm's toolbelt. The artifact is the
      # file the agent wrote; it is harvested into results/generated/ (an
      # absent/empty artifact becomes a truthful placeholder that renders
      # blank - a recorded outcome, never a crash). Returns the manifest
      # entry. Blast-radius rule: infra failures retry, then the unit is
      # recorded as an error entry by the caller.
      def generate_unit(task:, brief:, arm:)
        host = host_root(arm)
        prompt = self.class.generation_prompt(task: task, brief: brief)
        self.class.assert_hermetic!(host, prompt: prompt) if arm == "raw_tailwind"
        view = host.join("app/views/eval/#{task}.html.erb")
        FileUtils.rm_f(view)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          envelope = claude_generate(prompt, host: host, toolbelt: TOOLBELTS.fetch(arm))
          {
            "cost_usd" => envelope["total_cost_usd"].to_f.round(4),
            "num_turns" => envelope["num_turns"],
            "duration_s" => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1),
            "attempts" => envelope.fetch("poetry_bench_attempts"),
            "artifact" => view.exist? && view.size.positive?
          }
        ensure
          # Even a unit that errored out leaves its truthful artifact (the
          # file it wrote, or a placeholder that renders blank) so every
          # downstream stage still sees a complete pair.
          harvest(view, task, arm)
        end
      end

      # The ONE generation prompt - no arm parameter can exist, so no arm
      # conditional can creep in. Everything arm-specific reaches the agent
      # through its host's own files (AGENTS.md et al).
      def self.generation_prompt(task:, brief:)
        <<~PROMPT
          You are building one view in this Rails application.

          Read AGENTS.md first and follow how UI is built in this app.

          The brief: #{brief}

          Write the finished template to app/views/eval/#{task}.html.erb (create the file; overwrite if present).

          Rules:
          - One self-contained ERB template. No partials, no layout code, no <script> tags, no external assets, nothing this application does not already provide.
          - Tailwind CSS v4 is compiled with full utility coverage for the classes you use.
          - If a behavior would need app JavaScript beyond what this application already wires, prefer native HTML capabilities (details/summary, popover, dialog, form controls, links).
          - The template renders inside the app layout on a desktop viewport (1024x768): compose the full section the brief describes.
          - When the file is written and final, reply with exactly: DONE
        PROMPT
      end

      # The hermeticity invariant, enforced at runtime (never a convention):
      # the raw_tailwind host's path, tree, and the prompt must not contain
      # the house name in any case. A leak here would un-blind the control
      # arm of the experiment.
      def self.assert_hermetic!(host_root, prompt: nil)
        leaks = []
        leaks << "prompt" if prompt&.downcase&.include?(HERMETIC_NEEDLE)
        leaks << "host path #{host_root}" if host_root.to_s.downcase.include?(HERMETIC_NEEDLE)
        Dir.glob(Pathname(host_root).join("**/*").to_s, File::FNM_DOTMATCH).each do |path|
          next unless File.file?(path)

          relative = Pathname(path).relative_path_from(host_root).to_s
          leaks << "file name #{relative}" if relative.downcase.include?(HERMETIC_NEEDLE)
          leaks << "file body #{relative}" if File.read(path).downcase.include?(HERMETIC_NEEDLE)
        end
        raise HermeticityError, "raw_tailwind host is not hermetic: #{leaks.uniq.join(", ")}" if leaks.any?
      end

      # ------------------------------------------------------------- aggregate

      GATE_BUCKET_RULES = {
        "slop" => /\A(?:design_slop|no_raw_colors)\z/,
        "a11y" => /
          aria|label|a11y|accessib|announc|semantic|landmark|focus|keyboard|
          heading|role|apg|reachable|hover|named|kbd
        /x,
        "content" => /content|described|title_and_body/
      }.freeze

      def self.gate_bucket(gate)
        GATE_BUCKET_RULES.each { |bucket, pattern| return bucket if gate.to_s.match?(pattern) }
        "structure"
      end

      # Fold the three stage outputs into the results-v1 payload. Pure -
      # unit-tested without any CLI. Only tasks judged AND scored count;
      # anything else is listed in "incomplete" rather than silently dropped.
      def self.aggregate(scorecard:, verdicts:, manifest:, meta: {})
        judged = verdicts.fetch("tasks", {})
        tasks = judged.keys.select { |task| scorecard.dig("tasks", task, "arms")&.size&.== 2 }.sort
        arms = ARM_HOSTS.keys

        records = tasks.to_h do |task|
          [task, {
            "brief" => judged[task]["brief"],
            "generation" => manifest.dig("units", task) || {},
            "gates" => arms.to_h { |arm| [arm, scorecard.dig("tasks", task, "arms", arm, "cross_arm")] },
            "verdict" => judged[task]["verdict"],
            "axes" => axis_winners(judged[task]["axis_tallies"]),
            "swap_consistency" => judged[task]["swap_consistency"]
          }]
        end

        overall = records.values.map { |record| record["verdict"] }.tally
        decided = records.values.reject { |record| UNDECIDED.include?(record["verdict"]) }
        wins = decided.count { |record| record["verdict"] == "poetry" }
        rates = gate_pass_rates(records, arms)

        {
          "schema" => SCHEMA,
          "meta" => meta,
          "tasks" => records,
          "incomplete" => (judged.keys - tasks).sort,
          "summary" => {
            "overall" => overall,
            "win_rate" => {
              "poetry_headline" => ratio(wins, records.size),
              "poetry_decided" => ratio(wins, decided.size)
            },
            "axes" => axis_summary(records, arms),
            "gate_pass_rates" => rates,
            "gate_deltas_ranked" => gate_deltas(rates, arms),
            "bucket_deltas" => bucket_deltas(records, arms),
            "failure_taxonomy" => failure_taxonomy(records, arms)
          },
          "predictions" => predictions(records, arms, wins)
        }
      end

      def self.predictions(records, arms, wins)
        bucket = bucket_deltas(records, arms)
        top_two = bucket.keys.first(2).sort
        raw_composition = records.select { |_, record| record["axes"]["composition"] == "raw_tailwind" }.keys
        {
          "p1_overall" => {
            "registered" => "poetry wins overall >= 70%",
            "observed" => ratio(wins, records.size),
            "held" => !records.empty? && wins.fdiv(records.size) >= 0.70
          },
          "p2_widest_gaps" => {
            "registered" => "gate pass-rate gap widest on a11y + design-slop",
            "observed_bucket_deltas" => bucket,
            "held" => top_two == %w[a11y slop]
          },
          "p3_blocks_signal" => {
            "registered" => "raw_tailwind winning any composition axis is the Blocks signal ",
            "tasks_where_raw_won_composition" => raw_composition,
            "triggered" => raw_composition.any?
          }
        }
      end

      # Per-axis winner for one task: the arm with more votes on that axis;
      # a tie is honest ("tied").
      def self.axis_winners(axis_tallies)
        (axis_tallies || {}).transform_values do |tally|
          best = tally.max_by { |_, votes| votes }
          tally.values.count(best.last) > 1 ? "tied" : best.first
        end
      end

      def self.axis_summary(records, arms)
        Judge::AXES.to_h do |axis|
          winners = records.values.map { |record| record["axes"][axis] }
          [axis, (arms + ["tied"]).to_h { |winner| [winner, winners.count(winner)] }]
        end
      end

      # Pass rate per gate NAME per arm, across every task the gate ran in
      # (gate names recur across tasks: focus_visible_treatment, design_slop,
      # content_complete...).
      def self.gate_pass_rates(records, arms)
        arms.to_h do |arm|
          runs = Hash.new { |hash, key| hash[key] = [] }
          records.each_value do |record|
            (record.dig("gates", arm) || {}).each { |gate, pass| runs[gate] << pass }
          end
          [arm, runs.sort.to_h { |gate, passes| [gate, ratio(passes.count(true), passes.size)] }]
        end
      end

      # Gates ranked by how much more often the poetry arm passes them -
      # the pre-registered "gate pass-rate gap" surface, per gate.
      def self.gate_deltas(rates, arms)
        lead, trail = arms
        rows = rates.fetch(lead).filter_map do |gate, entry|
          other = rates.dig(trail, gate)
          next unless other

          { "gate" => gate, "bucket" => gate_bucket(gate),
            "delta" => (entry["rate"] - other["rate"]).round(3), "runs" => entry["of"] }
        end
        rows.sort_by { |row| [-row["delta"], row["gate"]] }
      end

      # Bucket-level pass-rate deltas (poetry minus raw), sorted widest
      # first - the mechanical check behind prediction p2.
      def self.bucket_deltas(records, arms)
        lead, trail = arms
        totals = Hash.new { |hash, key| hash[key] = { lead => [], trail => [] } }
        records.each_value do |record|
          arms.each do |arm|
            (record.dig("gates", arm) || {}).each { |gate, pass| totals[gate_bucket(gate)][arm] << pass }
          end
        end
        deltas = totals.to_h do |bucket, passes|
          delta = passes[lead].count(true).fdiv(passes[lead].size) -
                  passes[trail].count(true).fdiv(passes[trail].size)
          [bucket, delta.round(3)]
        end
        deltas.sort_by { |_, delta| -delta }.to_h
      end

      def self.failure_taxonomy(records, arms)
        arms.to_h do |arm|
          failed = Hash.new { |hash, key| hash[key] = [] }
          records.each do |task, record|
            (record.dig("gates", arm) || {}).each { |gate, pass| failed[gate] << task unless pass }
          end
          [arm, failed.sort_by { |_, tasks| -tasks.size }.to_h]
        end
      end

      def self.ratio(numerator, denominator)
        { "n" => numerator, "of" => denominator,
          "rate" => denominator.zero? ? nil : numerator.fdiv(denominator).round(3) }
      end

      private

      # ---------------------------------------------------------- host content

      def write_common_files
        ARM_HOSTS.each_key do |arm|
          host_root(arm).join("CLAUDE.md").write(COMMON_CLAUDE_MD)
          host_root(arm).join("app/views/eval/.keep").write("")
        end
      end

      def write_host_a
        host = host_root("poetry")
        registry = Poetry::Core::Registry.new(source_root: @ui_root)
        llms = Poetry::Core::LlmsText.new(registry: registry)
        host.join("llms.txt").write(llms.index)
        host.join("llms-full.txt").write(llms.full)
        host.join("AGENTS.md").write(<<~MD + agents_section_text)
          # AGENTS.md

          Rails 8 + Tailwind CSS v4 application. UI is built with the poetry
          component library (ViewComponent + Stimulus helpers).

          Fixture notes (this checkout has no booted server):

          - The machine catalog routes are materialized as files here:
            `/poetry/llms.txt` -> `llms.txt`, `/poetry/llms-full.txt` -> `llms-full.txt`.
          - Run the markup linter as `bin/check app/views/eval/<file>.html.erb`
            (wraps `bin/rails poetry:check`).

        MD
        write_bin_check(host)
      end

      def write_host_b
        host_root("raw_tailwind").join("AGENTS.md").write(<<~MD)
          # AGENTS.md

          Rails 8 + Tailwind CSS v4 application. UI is hand-authored: semantic
          HTML with Tailwind utility classes directly in the ERB templates -
          there is no component library in this app.

          - Views live under `app/views/`.
          - The full Tailwind v4 utility set is available.
          - Keep markup semantic and accessible.
        MD
      end

      # The canonical marker-bounded AGENTS.md section, from the same module
      # `rails g poetry:agents` uses - the host shows agents exactly what an
      # installed app shows them.
      def agents_section_text
        Object.new.extend(Poetry::Generators::AgentsSection).agents_section
      end

      def write_bin_check(host)
        bin = host.join("bin")
        FileUtils.mkdir_p(bin)
        check = bin.join("check")
        check.write(<<~SH)
          #!/usr/bin/env bash
          # Markup linter (fixture wrapper for `bin/rails poetry:check`).
          set -euo pipefail
          target="${1:?usage: bin/check <template.html.erb>}"
          case "$target" in /*) abs="$target" ;; *) abs="$PWD/$target" ;; esac
          cd #{@ui_root.to_s.inspect} && exec bundle exec rake "poetry:check[$abs]"
        SH
        check.chmod(0o755)
      end

      # ------------------------------------------------------------- CLI calls

      def harvest(view, task, arm)
        target = generated_root.join(task, "#{arm}.html.erb")
        FileUtils.mkdir_p(target.dirname)
        if view.exist? && view.size.positive?
          FileUtils.cp(view, target)
        else
          target.write("<%# generation produced no artifact %>\n")
        end
      end

      # One generation agent through the claude CLI. Usage is receipted the
      # moment an envelope parses (cost is spent even when the envelope
      # reports an error); MAX_GENERATION_ATTEMPTS retries, then the caller
      # records the unit as an error entry - never a run killer.
      def claude_generate(prompt, host:, toolbelt:, attempt: 1)
        out, err, status = Open3.capture3(
          "claude", "-p", prompt, "--output-format", "json",
          "--model", @model, "--max-turns", @max_turns.to_s,
          "--allowedTools", toolbelt,
          chdir: host.to_s
        )
        unless status.success?
          raise Error, "claude exited #{status.exitstatus}: #{err.to_s[0, 200]} #{out.to_s[0, 200]}".strip
        end

        envelope = JSON.parse(out)
        record_usage(envelope)
        raise Error, "claude errored: #{envelope["result"].to_s[0, 200]}" if envelope["is_error"]

        envelope.merge("poetry_bench_attempts" => attempt)
      rescue Error, JSON::ParserError => e
        raise Error, "generation failed after #{attempt} attempts: #{e.message}" if attempt >= MAX_GENERATION_ATTEMPTS

        claude_generate(prompt, host: host, toolbelt: toolbelt, attempt: attempt + 1)
      end

      def record_usage(envelope)
        @usage_mutex.synchronize do
          @calls += 1
          @receipted_cost_usd += envelope["total_cost_usd"].to_f
        end
      end
    end
  end
end
