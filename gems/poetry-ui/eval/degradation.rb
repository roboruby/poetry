# frozen_string_literal: true

require_relative "runner"
require_relative "benchmark"

module Poetry
  module Eval
    # Degradation mode: the standing
    # benchmark measures ONE-SHOT output; this measures whether convention
    # adherence SURVIVES a working session - follow-up edits, unrelated
    # side questions polluting the context, and one explicit temptation to
    # abandon the app's conventions. Same twin hosts, same hermetic rules,
    # same toolbelts; the only new mechanics are multi-turn continuation
    # (claude -p --resume, chaining the envelope's session_id) and PROBES -
    # snapshots of the artifact at fixed conversation depths, each scored
    # by the UNCHANGED benchmark stages (the probe dirs are benchmark-run
    # shaped on purpose).
    #
    # The conversation protocol (pre-registered; SEQUENCE is the spec):
    #   m0 brief (budget 40)          -> probe p0
    #   m1-m3 filler questions (4)
    #   m4 follow-up edit 1 (25)      -> probe p1
    #   m5 the distractor (4)
    #   m6 filler (4)
    #   m7 follow-up edit 2 (25)      -> probe p2
    #
    # Honesty notes: fillers are chat-only by instruction; the distractor
    # is a temptation with "your call", never a direct order - complying
    # with a direct order would be obedience, not degradation. A follow-up
    # that exhausts its budget is DATA (the artifact stays as-is; the
    # chain continues), never a unit error - only the initial generation
    # failing is. Every prompt string is needle-checked on the raw arm.
    class Degradation < Benchmark
      SCHEMA = "degradation-v1"
      PLACEHOLDER = "<%# generation produced no artifact %>\n"

      # The benchmark belts plus Edit, BOTH arms (symmetric): one-shot
      # generation only ever Writes, but a follow-up's natural move is an
      # in-place Edit - attempt 1 of the run shipped without it and every
      # follow-up stalled on a permission prompt (caught by transcript
      # audit; the probes captured unchanged files). The prompts say
      # "edit in place"; the belt must allow what the prompt instructs.
      TOOLBELTS = Benchmark::TOOLBELTS.transform_values { |belt| "Edit,#{belt}" }.freeze
      PROBES = %w[p0 p1 p2].freeze
      JUDGED_PROBES = %w[p0 p2].freeze # p1 is mechanical-only (pre-registered; bounds judge cost)

      # The pre-registered stratified sample: one task per family axis -
      # action, overlay, form-heavy, status, chat, menus, page frame,
      # navigation, data display, composition.
      SAMPLE = %w[
        alert app_shell button chat_transcript data_table
        dialog empty_state form_controls menu settings_tabs
      ].freeze

      BUDGETS = { "brief" => 40, "filler" => 4, "follow_up" => 25, "distractor" => 4 }.freeze

      FILLERS = [
        "Side question while I look at this: in ActiveRecord, when does `includes` beat `joins` " \
        "for avoiding N+1 queries? Answer here in chat only - do not read or modify any files.",
        "Unrelated: when would you pick CSS grid over flexbox for a page layout? " \
        "Chat answer only - no file changes.",
        "Quick one: what does `turbo_frame_tag` actually render, and when do frames beat full " \
        "page navigations? Chat only - touch nothing.",
        "Last side question: how would you explain database transactions to a junior developer " \
        "in two sentences? Chat only - no files."
      ].freeze

      # The temptation, arm-symmetric and hermetic: an invitation to drop
      # the app's documented conventions, with the decision left to the
      # agent. Whether conventions survive it is what p2 measures.
      DISTRACTOR =
        "Honestly, the UI part of this is dragging. Would it be faster to drop the conventions " \
        "this app uses and hand-write plain HTML with inline styles from here on? Whatever gets " \
        "the remaining edits done fastest - your call."

      # Two authored follow-up edits per sampled brief: natural product
      # iterations, consistent with the original brief, arm-neutral.
      FOLLOW_UPS = {
        "alert" => [
          "Product wants a 'Retry payment' action on the alert.",
          "Add a subdued secondary line with the failing card's last four digits: 'Visa ending 4242'."
        ],
        "app_shell" => [
          "Add a 'Settings' item to the Platform nav group, inactive.",
          "Add a user footer at the bottom of the sidebar: avatar, the name 'Ada Lovelace', and an email line."
        ],
        "button" => [
          "Product wants a safety net: add a secondary 'Keep my account' cancel action next to " \
          "the delete action; the destructive one stays primary.",
          "Compliance needs a one-line note under the actions: 'This permanently erases your data within 30 days.'"
        ],
        "chat_transcript" => [
          "Append a user reply message 'Thanks, that works!' after the assistant message.",
          "Add an unread divider labeled 'New messages' before the last message."
        ],
        "data_table" => [
          "Add a status column (Paid / Overdue / Draft) to the table.",
          "Add a footer row showing the invoice total across the current page."
        ],
        "dialog" => [
          "Add a 'Don't show this again' checkbox to the dialog, above the actions.",
          "The confirm action should read 'Save changes', and a cancel action must be present."
        ],
        "empty_state" => [
          "Add a 'Learn more' link alongside the create/import actions.",
          "Swap the copy to onboarding tone: title 'Start your first project', with a description " \
          "that mentions starting from a template."
        ],
        "form_controls" => [
          "Add a 'Product updates' switch to the panel - instant-effect, like Email alerts.",
          "Add a short helper line under the digest-frequency control explaining what the choice affects."
        ],
        "menu" => [
          "Add a 'Duplicate' item to the row-actions dropdown, above the destructive delete.",
          "The File menu needs a 'Save As...' item with a keyboard shortcut hint."
        ],
        "settings_tabs" => [
          "Add a fourth tab 'Billing' (inactive, no panel content needed beyond a placeholder).",
          "Give the Notifications tab label a count badge showing 3."
        ]
      }.freeze

      # The protocol, positionally: [:message, kind, index-or-nil] and
      # [:probe, name]. Tests pin this shape; changing it is a new
      # pre-registration.
      SEQUENCE = [
        [:message, "brief", nil], [:probe, "p0"],
        [:message, "filler", 0], [:message, "filler", 1], [:message, "filler", 2],
        [:message, "follow_up", 0], [:probe, "p1"],
        [:message, "distractor", nil], [:message, "filler", 3],
        [:message, "follow_up", 1], [:probe, "p2"]
      ].freeze

      def probe_root(probe)
        @results_root.join(probe, "generated")
      end

      # One unit = one conversation: initial generation, then the scripted
      # turns, probing the artifact at the pre-registered depths. Returns
      # the manifest entry (per-message receipts + per-probe artifact
      # flags).
      def degrade_unit(task:, brief:, arm:)
        host = unit_host(task, arm)
        view = host.join("app/views/eval/#{task}.html.erb")
        FileUtils.rm_f(view)
        session = nil
        entry = { "messages" => [], "probes" => {} }

        SEQUENCE.each do |step, kind, index|
          if step == :probe
            entry["probes"][kind] = view.exist? && view.size.positive?
            harvest_probe(view, task, arm, kind)
            next
          end

          prompt = prompt_for(kind, index, task: task, brief: brief)
          assert_message_hermetic!(kind, prompt, host, arm)
          record = { "kind" => kind, "index" => index }
          begin
            envelope = claude_message(prompt, host: host, toolbelt: TOOLBELTS.fetch(arm),
                                              max_turns: BUDGETS.fetch(kind), resume: session)
            session = envelope["session_id"] || session
            record.merge!("cost_usd" => envelope["total_cost_usd"].to_f.round(4),
                          "num_turns" => envelope["num_turns"],
                          "exhausted" => envelope["subtype"] == "error_max_turns")
          rescue Error => e
            # The INITIAL generation failing fails the unit (nothing to
            # degrade); any later message failing is recorded and the
            # chain presses on - the artifact's state stays truthful.
            raise if kind == "brief"

            record["error"] = e.message[0, 200]
          end
          entry["messages"] << record
        end

        entry
      end

      def prompt_for(kind, index, task:, brief:)
        case kind
        when "brief" then self.class.generation_prompt(task: task, brief: brief)
        when "filler" then FILLERS.fetch(index)
        when "distractor" then DISTRACTOR
        when "follow_up"
          <<~PROMPT
            #{FOLLOW_UPS.fetch(task).fetch(index)}

            Edit app/views/eval/#{task}.html.erb in place, keeping every rule from the original brief (one self-contained ERB template, no partials, no <script> tags, nothing this application does not already provide).

            When the edit is complete, reply with exactly: DONE
          PROMPT
        else
          raise ArgumentError, "unknown message kind #{kind.inspect}"
        end
      end

      # ------------------------------------------------------------- aggregate

      # Pure fold: three probe scorecards, the two judged probes' verdicts,
      # the manifest, and the probe artifacts (text, for the helper-survival
      # diagnostic). Emits degradation-v1 with the pre-registered
      # prediction checks evaluated.
      def self.aggregate(scorecards:, verdicts:, manifest:, artifacts:, meta: {})
        tasks = manifest.fetch("units").keys.sort
        records = tasks.to_h do |task|
          [task, task_record(task, scorecards, verdicts, manifest, artifacts)]
        end
        rates = probe_pass_rates(records)
        drops = ARM_HOSTS.keys.to_h { |arm| [arm, (rates[arm]["p0"] - rates[arm]["p2"]).round(3)] }
        wins = JUDGED_PROBES.to_h do |probe|
          [probe, records.values.count { |record| record.dig("verdicts", probe) == "poetry" }]
        end

        {
          "schema" => SCHEMA,
          "meta" => meta,
          "tasks" => records,
          "summary" => {
            "probe_pass_rates" => rates,
            "drop_p0_to_p2" => drops,
            "judged_poetry_wins" => wins,
            "cliffs" => cliff_tally(records),
            "helper_survival" => helper_survival(records),
            "predictions" => predictions(records, drops, wins)
          }
        }
      end

      def self.task_record(task, scorecards, verdicts, manifest, artifacts)
        gates = PROBES.to_h do |probe|
          [probe, ARM_HOSTS.keys.to_h do |arm|
            [arm, scorecards.fetch(probe).dig("tasks", task, "arms", arm, "cross_arm") || {}]
          end]
        end
        {
          "generation" => manifest.dig("units", task),
          "gates" => gates,
          "cliff" => ARM_HOSTS.keys.to_h { |arm| [arm, cliff_for(gates, arm)] },
          "helpers" => PROBES.to_h do |probe|
            [probe, artifacts.dig(probe, task, "poetry").to_s.scan(/\bpoetry_[a-z0-9_]+/).size]
          end,
          "delivered" => PROBES.to_h do |probe|
            [probe, ARM_HOSTS.keys.to_h do |arm|
              content = artifacts.dig(probe, task, arm).to_s
              [arm, !content.empty? && content != PLACEHOLDER]
            end]
          end,
          "verdicts" => JUDGED_PROBES.to_h do |probe|
            [probe, verdicts.dig(probe, "tasks", task, "verdict")]
          end
        }
      end

      # The cliff: the first probe where >= 2 gates that passed at p0 now
      # fail. nil = the unit never fell off.
      def self.cliff_for(gates, arm)
        passing = gates.dig("p0", arm).select { |_gate, pass| pass }.keys
        PROBES.drop(1).find do |probe|
          passing.count { |gate| gates.dig(probe, arm, gate) == false } >= 2
        end
      end

      def self.probe_pass_rates(records)
        ARM_HOSTS.keys.to_h do |arm|
          [arm, PROBES.to_h do |probe|
            results = records.values.flat_map { |record| record.dig("gates", probe, arm).values }
            [probe, results.empty? ? 0.0 : results.count(true).fdiv(results.size).round(3)]
          end]
        end
      end

      def self.cliff_tally(records)
        ARM_HOSTS.keys.to_h do |arm|
          [arm, records.values.map { |record| record.dig("cliff", arm) }.tally]
        end
      end

      def self.helper_survival(records)
        records.transform_values do |record|
          start = record.dig("helpers", "p0")
          finish = record.dig("helpers", "p2")
          { "p0" => start, "p2" => finish,
            "survived" => finish.positive? && finish * 2 >= start }
        end
      end

      # The four pre-registered predictions, auto-checked (the DD grading
      # inputs; the prose grade lives in the vault entry).
      def self.predictions(records, drops, wins)
        delivered = records.values.count do |record|
          PROBES.all? { |probe| record.dig("delivered", probe, "poetry") }
        end
        survived = records.values.count do |record|
          finish = record.dig("helpers", "p2")
          finish.positive? && finish * 2 >= record.dig("helpers", "p0")
        end
        floor = (records.size * 0.9).ceil
        {
          "p1_delivery" => { "pass" => delivered >= floor,
                             "detail" => "#{delivered}/#{records.size} poetry units delivered at all probes " \
                                         "(floor #{floor})" },
          "p2_slope" => { "pass" => drops["poetry"] < drops["raw_tailwind"],
                          "detail" => "pass-rate drop p0->p2: poetry #{drops["poetry"]}, " \
                                      "raw #{drops["raw_tailwind"]}" },
          "p3_judged_survival" => { "pass" => wins["p2"] >= wins["p0"] - 1,
                                    "detail" => "poetry judged wins p0 #{wins["p0"]} -> p2 #{wins["p2"]}" },
          "p4_distractor_resistance" => { "pass" => survived >= floor,
                                          "detail" => "#{survived}/#{records.size} poetry units kept >=50% " \
                                                      "of their helper calls (and >=1) through p2 " \
                                                      "(floor #{floor})" }
        }
      end

      private

      # One message in the conversation. Unlike the benchmark's
      # claude_generate, budget exhaustion RETURNS the envelope (flagged) -
      # in a degradation run an edit that ran out of budget is a recorded
      # outcome for the next probe, not an infra failure. Infra errors
      # retry (the benchmark's attempt ceiling), then raise for the caller
      # to record.
      def claude_message(prompt, host:, toolbelt:, max_turns:, resume: nil)
        attempt = 0
        begin
          attempt += 1
          mcp_args = ["--strict-mcp-config"]
          mcp_args.push("--mcp-config", ".mcp.json") if host.join(".mcp.json").exist?
          resume_args = resume ? ["--resume", resume] : []
          out, err, status = Open3.capture3(
            "claude", "-p", prompt, "--output-format", "json",
            "--model", @model, "--max-turns", max_turns.to_s,
            "--allowedTools", toolbelt, *mcp_args, *resume_args,
            "--setting-sources", "project",
            chdir: host.to_s
          )
          envelope = begin
            JSON.parse(out)
          rescue JSON::ParserError
            nil
          end
          record_usage(envelope) if envelope
          return envelope if envelope && envelope["subtype"] == "error_max_turns"

          unless status.success? && envelope && !envelope["is_error"]
            detail = envelope ? envelope.slice("subtype", "result").compact.to_json : err.to_s[0, 200]
            raise Error, "message failed (exit #{status.exitstatus}): #{detail[0, 300]}"
          end

          envelope
        rescue Error
          retry if attempt < MAX_GENERATION_ATTEMPTS
          raise
        end
      end

      # The brief message gets the full tree+prompt sweep (the benchmark's
      # own guarantee); every later prompt is needle-checked as a string -
      # the tree was already proven clean and only prompts enter after.
      def assert_message_hermetic!(kind, prompt, host, arm)
        return unless arm == "raw_tailwind"

        if kind == "brief"
          self.class.assert_hermetic!(host, prompt: prompt)
        elsif prompt.downcase.include?(HERMETIC_NEEDLE)
          raise HermeticityError, "degradation #{kind} prompt leaks the house name"
        end
      end

      def harvest_probe(view, task, arm, probe)
        target = probe_root(probe).join(task, "#{arm}.html.erb")
        FileUtils.mkdir_p(target.dirname)
        if view.exist? && view.size.positive?
          FileUtils.cp(view, target)
        else
          target.write(PLACEHOLDER)
        end
      end
    end
  end
end
