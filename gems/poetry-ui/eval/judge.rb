# frozen_string_literal: true

require "json"
require "shellwords"
require "fileutils"
require "tmpdir"

module Poetry
  module Eval
    # The paired LLM judge (the second half of 's harness). The
    # Design Crit finding is load-bearing: off-the-shelf judges score near
    # chance on ABSOLUTE design quality but are usable on PAIRED comparison
    # with concrete axes - so the judge only ever ranks two candidates for
    # the same brief, per axis, forced-choice.
    #
    # The A/B honesty rule at the judge layer: the judge sees the brief,
    # both screenshots, and both CROSS-ARM gate ledgers - never the
    # poetry_only diagnostics, never which arm is which. Captures are
    # copied to position-named tmp files before the call because the real
    # capture paths carry arm names; assert_blind! makes the invariant a
    # runtime error, not a convention.
    #
    # Anti-bias harness: VOTES_PER_ORDER votes in each presentation order
    # (A/B then B/A). The claude CLI exposes no temperature control, so the
    # position-swap discipline carries the determinism load: a verdict that
    # only ever appears in one presentation order is position-biased and
    # discarded; majority of surviving votes decides; no survivors =
    # inconclusive (an honest verdict class, reported not hidden).
    class Judge
      SCHEMA = "judge-v1"
      AXES = %w[hierarchy composition clarity brief_fit].freeze
      VOTES_PER_ORDER = 3
      DEFAULT_MODEL = "claude-sonnet-5"
      POSITIONS = %w[first second].freeze
      MALFORMED = "malformed"
      MAX_VOTE_ATTEMPTS = 3

      class Error < StandardError; end

      # The staging workdir defaults OUTSIDE the repo: the repo path itself
      # contains "poetry", so in-repo staging would leak the house name to
      # the judge (assert_blind! catches exactly this).
      def initialize(model: ENV.fetch("POETRY_JUDGE_MODEL", DEFAULT_MODEL),
                     votes_per_order: VOTES_PER_ORDER,
                     workdir: File.join(Dir.tmpdir, "ui-eval-judge"))
        @model = model
        @votes_per_order = votes_per_order
        @workdir = Pathname(workdir)
        @cost_mutex = Mutex.new
        @total_cost_usd = 0.0
        @calls = 0
      end

      attr_reader :model, :votes_per_order, :total_cost_usd, :calls

      # arms: exactly two entries, { "<arm id>" => { "capture" => <png path>,
      # "ledger" => { "<gate>" => true/false } } }. Returns the task verdict
      # record (votes, verdict, axis tallies, swap consistency).
      #
      # Blast radius rule (learned when call ~180 of a 186-call run raised):
      # a vote that stays malformed after MAX_VOTE_ATTEMPTS becomes a
      # DISCARDED vote - recorded, counted against swap-consistency, never
      # fatal. Only staging/setup errors abort a pair.
      def judge_pair(task:, brief:, arms:)
        ids = arms.keys
        raise Error, "judge_pair needs exactly two arms, got #{ids.inspect}" unless ids.size == 2

        votes = %i[ab ba].flat_map do |order|
          pair = order == :ab ? ids : ids.reverse
          prompt = staged_prompt(task, order, brief, pair, arms)
          Array.new(@votes_per_order) do
            normalize_vote(claude_vote(prompt), pair, order)
          rescue Error => e
            { "overall" => MALFORMED, "axes" => {}, "order" => order.to_s,
              "rationale" => "discarded: #{e.message[0, 200]}" }
          end
        end
        { "brief" => brief, "arms" => ids, "votes" => votes,
          "axis_tallies" => self.class.axis_tallies(votes, ids) }.merge(self.class.tally(votes))
      end

      # --- the vote math (pure; unit-tested without the CLI) ---------------

      # Fold a full vote set (malformed markers included) into the verdict
      # fragment: malformed votes leave the decide pool but count against
      # swap-consistency - a judge that can't emit a valid vote spent one.
      def self.tally(votes)
        valid = votes.reject { |vote| vote["overall"] == MALFORMED }
        decision = decide(valid)
        { "verdict" => decision[:verdict],
          "surviving_votes" => decision[:surviving],
          "swap_consistency" => votes.empty? ? 0.0 : (decision[:surviving].to_f / votes.size).round(3),
          "malformed_votes" => votes.size - valid.size }
      end

      # A verdict group survives only if it drew votes in BOTH presentation
      # orders; the majority of surviving votes decides; a tie between
      # surviving groups (or no survivor) is inconclusive.
      def self.decide(votes)
        groups = votes.group_by { |vote| vote["overall"] }
        surviving = groups.select { |_, members| members.map { |vote| vote["order"] }.uniq.size == 2 }
        pool = surviving.values.flatten
        best = surviving.max_by { |_, members| members.size }
        verdict =
          if best.nil? || surviving.count { |_, members| members.size == best.last.size } > 1
            "inconclusive"
          else
            best.first
          end
        { verdict: verdict, surviving: pool.size,
          swap_consistency: votes.empty? ? 0.0 : (pool.size.to_f / votes.size).round(3) }
      end

      def self.axis_tallies(votes, ids)
        AXES.to_h do |axis|
          [axis, ids.to_h { |id| [id, votes.count { |vote| vote.dig("axes", axis) == id }] }]
        end
      end

      # Map a raw first/second vote back to arm ids for the given
      # presentation pair (pair[0] was shown FIRST).
      def self.normalize(raw, pair)
        lookup = { "first" => pair[0], "second" => pair[1] }
        overall = lookup[raw["overall"]]
        raise Error, "vote overall must be first/second, got #{raw.inspect}" unless overall

        axes = AXES.to_h do |axis|
          value = lookup[raw.dig("axes", axis)]
          raise Error, "vote axis #{axis} must be first/second: #{raw.inspect}" unless value

          [axis, value]
        end
        { "overall" => overall, "axes" => axes, "rationale" => raw["rationale"].to_s }
      end

      # The blind-judging invariant, enforced at runtime: the prompt must
      # not name an arm or point at a path that does.
      def self.assert_blind!(prompt, forbidden)
        leaks = forbidden.select { |needle| prompt.downcase.include?(needle.downcase) }
        raise Error, "judge prompt leaks arm identity: #{leaks.inspect}" if leaks.any?

        prompt
      end

      def self.build_prompt(brief:, first_path:, second_path:, first_ledger:, second_ledger:)
        <<~PROMPT
          You are judging two candidate UI implementations of the same brief in a paired design-quality comparison.

          The brief: #{brief}

          The two candidates, screenshotted in the same browser at the same viewport (a screenshot may show the
          surface mid-interaction - e.g. an opened dialog or menu - because the capture rig clicked the primary
          trigger on both candidates identically; a candidate whose trigger did nothing shows that truth):
          - FIRST: #{first_path}
          - SECOND: #{second_path}

          Read both screenshot files now.

          Deterministic gate results already measured on each candidate's DOM (identical checks, both candidates):
          FIRST:  #{first_ledger}
          SECOND: #{second_ledger}

          Pick the better candidate on each axis, then overall:
          - hierarchy: clearer visual hierarchy (type scale, weight, spacing carrying the structure)
          - composition: better composed (alignment, grouping, balance, use of space)
          - clarity: communicates purpose more clearly (affordances, labels, visible states)
          - brief_fit: fulfills the brief more completely and correctly (the gate results count here)
          - overall: all things considered

          Rules:
          - FORCED CHOICE: every answer is exactly "first" or "second" - no ties, no abstentions.
          - Judge what you can SEE plus the gate ledger; do not speculate about the underlying code.
          - Output ONLY one JSON object, no prose before or after it:
          {"overall":"first|second","axes":{"hierarchy":"first|second","composition":"first|second","clarity":"first|second","brief_fit":"first|second"},"rationale":"<= 2 sentences"}
        PROMPT
      end

      # Pull the JSON object out of a model reply. Tolerates code fences and
      # the observed trailing-garbage shape (a dangling `,"` before the
      # closing brace - seen live from the judge model mid-calibration).
      def self.extract_json(text)
        body = text[/\{.*\}/m]
        raise Error, "no JSON object in judge reply: #{text.inspect}" unless body

        begin
          JSON.parse(body)
        rescue JSON::ParserError
          JSON.parse(body.sub(/,\s*"?\s*\}\s*\z/, "}"))
        end
      rescue JSON::ParserError => e
        raise Error, "unparseable judge reply (#{e.message}): #{text.inspect}"
      end

      def self.render_ledger(ledger)
        ledger.map { |gate, pass| "#{gate} #{pass ? "pass" : "FAIL"}" }.join(" | ")
      end

      private

      # Stage the two captures under position-named tmp paths (the real
      # capture paths carry arm names) and build the blinded prompt.
      def staged_prompt(task, order, brief, pair, arms)
        dir = @workdir.join(task.to_s, order.to_s)
        FileUtils.mkdir_p(dir)
        paths = POSITIONS.each_with_index.map do |position, index|
          staged = dir.join("#{position}.png")
          FileUtils.cp(arms.fetch(pair[index]).fetch("capture"), staged)
          staged.to_s
        end
        prompt = self.class.build_prompt(
          brief: brief, first_path: paths[0], second_path: paths[1],
          first_ledger: self.class.render_ledger(arms.fetch(pair[0]).fetch("ledger")),
          second_ledger: self.class.render_ledger(arms.fetch(pair[1]).fetch("ledger"))
        )
        forbidden = pair + arms.values.map { |arm| arm.fetch("capture").to_s }
        self.class.assert_blind!(prompt, forbidden)
      end

      def normalize_vote(raw, pair, order)
        vote = self.class.normalize(raw, pair)
        vote["order"] = order.to_s
        vote
      end

      # One judge vote through the claude CLI - print mode, JSON envelope,
      # Read-only toolbelt (the screenshots); MAX_VOTE_ATTEMPTS tries before
      # the caller downgrades the vote to a discarded one.
      def claude_vote(prompt, attempt: 1)
        command = "claude -p #{Shellwords.escape(prompt)} --output-format json " \
                  "--model #{Shellwords.escape(@model)} --allowedTools Read --max-turns 8 2>/dev/null"
        out = `#{command}`
        raise Error, "claude exited #{Process.last_status.exitstatus}" unless Process.last_status.success?

        envelope = JSON.parse(out)
        raise Error, "claude errored: #{envelope["result"].to_s[0, 200]}" if envelope["is_error"]

        record_usage(envelope)
        self.class.extract_json(envelope.fetch("result"))
      rescue Error, JSON::ParserError => e
        raise Error, "judge vote failed after #{attempt} attempts: #{e.message}" if attempt >= MAX_VOTE_ATTEMPTS

        claude_vote(prompt, attempt: attempt + 1)
      end

      def record_usage(envelope)
        @cost_mutex.synchronize do
          @calls += 1
          @total_cost_usd += envelope["total_cost_usd"].to_f
        end
      end
    end
  end
end
