# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "tmpdir"
require "pathname"
require_relative "judge"

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
    # - Unit isolation: every (task, arm) runs in its own fresh copy of the
    #   template host - units can never read sibling units' outputs (the
    #   shared-host pilot leaked finished views to later units, and the
    #   exposure was arm-asymmetric because raw arms finish first).
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
      # One budget, both arms. 40 because the poetry workflow legitimately
      # spends turns on its documented loop (read catalog -> write -> check
      # -> fix): at 24 the two heaviest briefs exhausted mid-loop while the
      # raw twin cruised at ~5-8 turns - a starved treatment arm measures
      # the cap, not the system.
      DEFAULT_MAX_TURNS = 40
      MAX_GENERATION_ATTEMPTS = 3
      HERMETIC_NEEDLE = "poetry"
      ARM_HOSTS = { "poetry" => "a", "raw_tailwind" => "b" }.freeze
      # The toolbelt asymmetry IS the treatment: host A's poetry surface is
      # runnable - bin/check plus the poetry MCP server ( remediation:
      # boot-free check/describe/list, attacking the turn-exhaustion tail
      # that cost menu/app_shell in the pre-registered run); host B has
      # nothing to run. `Skill` is in BOTH belts (Skills v1): the
      # asymmetry stays in the hosts' files - host A carries poetry's two
      # skills, host B has none, and --setting-sources project keeps
      # user-scoped skills out of both arms (the CLI's built-in skills
      # remain, a symmetric substrate).
      TOOLBELTS = {
        "poetry" => "Read,Glob,Grep,Write,Skill,Bash(bin/check:*)," \
                    "mcp__poetry__check,mcp__poetry__describe_component,mcp__poetry__list_components," \
                    "mcp__poetry__list_blocks,mcp__poetry__describe_block",
        "raw_tailwind" => "Read,Glob,Grep,Write,Skill"
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
      # Turn-budget exhaustion is deterministic at a fixed budget: retrying
      # it re-spends the whole budget for the same outcome, so it skips the
      # retry loop and records as an error unit (its cost still receipts -
      # the envelope carries total_cost_usd even on error_max_turns).
      class MaxTurnsError < Error; end

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
        require "generators/poetry/skills_section"

        ARM_HOSTS.each_key do |arm|
          # Reset the template's views dir: every unit gets a fresh COPY of
          # this template (unit_host), so nothing generated may sit here.
          views = host_root(arm).join("app/views/eval")
          FileUtils.rm_rf(views)
          FileUtils.mkdir_p(views)
        end
        write_common_files
        write_host_a
        write_host_b
        self.class.assert_hermetic!(host_root("raw_tailwind"))
        [host_root("poetry"), host_root("raw_tailwind")]
      end

      # ------------------------------------------------------------ generation

      # Generate one arm of one task: a fresh claude CLI agent in ITS OWN
      # copy of the arm's template host (unit isolation - a shared host let
      # late units read earlier units' finished views, and since raw arms
      # finish fast and ran first, the exposure was asymmetric; caught by
      # transcript audit mid-run and regenerated). The identical prompt,
      # the arm's toolbelt. The artifact is the file the agent wrote,
      # harvested into results/generated/ (an absent/empty artifact becomes
      # a truthful placeholder that renders blank - a recorded outcome,
      # never a crash). Returns the manifest entry. Blast-radius rule:
      # infra failures retry, then the unit is recorded as an error entry
      # by the caller.
      def generate_unit(task:, brief:, arm:)
        host = unit_host(task, arm)
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
          - Your tools are Read, Glob, Grep, and Write, plus any checking tools AGENTS.md documents. General shell commands are unavailable.
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
        registry = Poetry::Ui.registry
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
          - The `poetry` MCP server is configured in `.mcp.json` (per the section
            below) - its `check` tool takes ERB source directly and returns
            instantly; `bin/check` boots the app (~15s a run).

        MD
        write_bin_check(host)
        write_mcp_config(host)
        write_skills(host)
      end

      # The two Claude Code skills, written exactly as `rails g poetry:skill`
      # installs them (Skills v1) - host A's fourth agent surface.
      # Host B gets none; with --setting-sources project on both arms, the
      # project skills ARE the arm's whole non-built-in skill surface.
      def write_skills(host)
        design = Object.new.extend(Poetry::Generators::SkillsSection)
        { ".claude/skills/poetry" => Poetry::Ui.skill_files,
          ".claude/skills/poetry-design" => design.design_skill_files }.each do |dir, files|
          files.each do |relative, content|
            path = host.join(dir, relative)
            FileUtils.mkdir_p(path.dirname)
            path.write(content)
          end
        end
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

      # The poetry MCP server for host A: the fixture host has no
      # Gemfile of its own, so the server runs out of the gem checkout's
      # bundle - exactly what an installed app's plain
      # `bundle exec poetry-agent` resolves to. Loaded via --mcp-config +
      # --strict-mcp-config (both arms strict: arm B runs with NO servers,
      # so nothing user-scoped can leak into either arm).
      def write_mcp_config(host)
        host.join(".mcp.json").write(JSON.pretty_generate(
                                       "mcpServers" => {
                                         "poetry" => {
                                           "command" => "bundle",
                                           "args" => ["exec", "poetry-agent", @ui_root.to_s],
                                           "env" => { "BUNDLE_GEMFILE" => @ui_root.join("Gemfile").to_s }
                                         }
                                       }
                                     ))
      end

      # ------------------------------------------------------------- CLI calls

      # A fresh copy of the arm's template host for one unit: no sibling
      # views to crib from, no scratch leakage between units, safe under
      # concurrency. Path shape hosts_root/units/<task>/<a|b> keeps the
      # raw twin's path free of the house name.
      def unit_host(task, arm)
        template = host_root(arm)
        host = @hosts_root.join("units", task, ARM_HOSTS.fetch(arm))
        FileUtils.rm_rf(host)
        FileUtils.mkdir_p(host.dirname)
        FileUtils.cp_r(template, host)
        host
      end

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
        # --strict-mcp-config for BOTH arms: only the host's own .mcp.json
        # (host A) or no servers at all (host B) - user-scoped MCP servers
        # must never leak into either arm.
        mcp_args = ["--strict-mcp-config"]
        mcp_args.push("--mcp-config", ".mcp.json") if host.join(".mcp.json").exist?
        out, err, status = Open3.capture3(
          "claude", "-p", prompt, "--output-format", "json",
          "--model", @model, "--max-turns", @max_turns.to_s,
          "--allowedTools", toolbelt, *mcp_args,
          # Skills resolve from the unit host only: without this,
          # the operator's user-scoped skills leak into both arms (proven
          # in the 2026-07-09 smoke test).
          "--setting-sources", "project",
          chdir: host.to_s
        )
        # A failed run still emits an envelope on stdout (exit 1, is_error,
        # subtype) - parse it first so its spend receipts and its reason is
        # legible; only a non-envelope crash falls through to raw output.
        envelope = begin
          JSON.parse(out)
        rescue JSON::ParserError
          nil
        end
        record_usage(envelope) if envelope
        if envelope&.fetch("subtype", nil) == "error_max_turns"
          raise MaxTurnsError, "max turns (#{@max_turns}) exhausted, " \
                               "$#{envelope["total_cost_usd"].to_f.round(2)} spent"
        end
        unless status.success?
          detail = if envelope
                     envelope.slice("subtype",
                                    "result").compact.to_json
                   else
                     "#{err.to_s[0, 200]} #{out.to_s[0, 200]}"
                   end
          raise Error, "claude exited #{status.exitstatus}: #{detail[0, 300]}".strip
        end
        raise Error, "no envelope in claude output: #{out.to_s[0, 120]}" if envelope.nil?
        raise Error, "claude errored: #{envelope["result"].to_s[0, 200]}" if envelope["is_error"]

        envelope.merge("poetry_bench_attempts" => attempt)
      rescue MaxTurnsError
        raise
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
