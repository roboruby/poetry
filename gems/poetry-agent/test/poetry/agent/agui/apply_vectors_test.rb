# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # The reference client's message-assembly ("apply") tests as vectors
      # (test/fixtures/agui/1.0/vectors/apply--*.json): held history and
      # state in, events through a strict Pipeline into a Transcript, and
      # the messages, state, runs and next input out. Each was confirmed
      # against the reference itself. A vector Poetry answers differently on
      # purpose is named in DIVERGENCES with the reason; the list only shrinks.
      class ApplyVectorsTest < Minitest::Test
        # Vector key ("file:line:name") to why Poetry answers it differently.
        # The keys are the reference's own test titles, so they run long.
        # rubocop:disable-next Layout/LineLength
        DIVERGENCES = {
          "apply--default.activity:805:preserves existing order and appends new activities when replacing an owned set" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with array namespace" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with array namespace [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with empty scope" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with empty scope [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with foreign scope" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with foreign scope [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with mixed array" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with mixed array [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with non-array field" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with non-array field [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with null namespace" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with null namespace [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:883:updates matching IDs but preserves omitted foreign activities with primitive namespace" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:884:updates matching IDs but preserves omitted foreign activities with primitive namespace [repeated]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:889:reconciles empty snapshots with explicit authority null" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.activity:891:reconciles empty snapshots with explicit authority [\"a2ui-surface\"]" =>
            "the reference reads an @ag-ui/client snapshot metadata convention that scopes which activity types a snapshot may delete; it is application space, and Poetry follows state.mdx's per-role rule",
          "apply--default.snapshot-tool-order:339:MESSAGES_SNAPSHOT keeps tool results next to their calls > leaves one copy of a merge-duplicated call unanswered" =>
            "the reference keeps two held messages that share an id as two entries mapped to one snapshot copy; Poetry keeps one message per id",
          "apply--default.snapshot-tool-order:354:MESSAGES_SNAPSHOT keeps tool results next to their calls > moves one copy of a result the merge aliases twice and leaves the other" =>
            "the reference keeps two held messages that share an id as two entries mapped to one snapshot copy; Poetry keeps one message per id",
          "apply--default.snapshot-tool-order:920:keepToolResultsWithCalls > keeps a result in place after the second copy of an aliased call" =>
            "the reference keeps two held messages that share an id as two entries mapped to one snapshot copy; Poetry keeps one message per id",
          "apply--default.snapshot-tool-order:933:keepToolResultsWithCalls > moves detached results behind the right copy of an aliased call" =>
            "the reference keeps two held messages that share an id as two entries mapped to one snapshot copy; Poetry keeps one message per id",
          "apply--default.snapshot-tool-order:553:MESSAGES_SNAPSHOT keeps tool results next to their calls > does not move early results forward when their call id is reused across turns" =>
            "a snapshot that lists one id twice: the reference appends both copies, Poetry keeps one message per id",
          "apply--probes-a:0:an encrypted value naming an unknown entity creates nothing and draws no warning" =>
            "the spec says a consumer SHOULD warn when an encrypted value names nothing it holds; the reference is silent",
          "apply--probes-a:0:RUN_FINISHED success: result and named pendingToolCallIds reach the run; usage is not kept" =>
            "Poetry keeps the run's token usage on the run record; the reference keeps it nowhere"
        }.freeze

        OUTCOMES = { finished: "success", interrupted: "interrupt", cancelled: "cancelled" }.freeze

        # The transcript's runs in the vectors' shape.
        def self.wire_runs(transcript)
          transcript.runs.map do |run|
            {
              "runId" => run[:run_id], "outcome" => OUTCOMES[run[:status]], "result" => run[:result],
              "pendingToolCallIds" => run[:pending_tool_call_ids], "usage" => run[:usage],
              "interrupts" => (run[:interrupts] if run[:interrupts].any?),
              "error" => run[:error]&.transform_keys(&:to_s)&.compact
            }.compact
          end
        end

        # One vector: what its held history and events leave behind.
        def self.replay(vector)
          warnings = []
          initial = vector["initial"] || {}
          transcript = Transcript.new(on_warning: ->(warning) { warnings << warning.message })
          Array(initial["messages"]).each { |message| transcript.add_message(JSON.parse(JSON.generate(message))) }
          transcript.state = initial["state"] if initial.key?("state")
          outcome = AguiHelper.run_pipeline(vector["input"])
          warnings.concat(outcome[:warnings])
          outcome[:events].each { |event| transcript.apply(event) }
          messages = transcript.send(:stored_wire)
          {
            "error" => outcome[:error]&.message, "messages" => messages, "state" => transcript.state,
            "pendingInterrupts" => transcript.interrupts, "runs" => wire_runs(transcript),
            "newMessageIds" => messages.map { |message| message["id"] } -
              Array(initial["messages"]).map { |message| message["id"] },
            "nextInput" => { "messages" => transcript.messages_for_input, "state" => transcript.state },
            "warnings" => warnings
          }
        end

        # Every key the vector asserts that does not hold, with the first difference.
        def self.misses(vector, result)
          expect = vector["expect"]
          found = []
          if expect.key?("error")
            found << "error: wanted #{expect["error"].inspect}, got #{result["error"].inspect}" unless
              result["error"]&.include?(expect["error"])
          elsif result["error"]
            found << "unexpected rejection: #{result["error"]}"
          end
          binds = {}
          %w[messages state pendingInterrupts runs newMessageIds nextInput].each do |key|
            next unless expect.key?(key)

            difference = AguiHelper.subset_difference(expect[key], result[key], key, binds)
            found << difference if difference
          end
          Array(vector["warnings"]).each do |fragment|
            found << "warning missing: #{fragment}" unless result["warnings"].any? { |w| w.include?(fragment) }
          end
          found << "warnings: #{result["warnings"].join(" | ")}" if vector["noWarnings"] && result["warnings"].any?
          found
        end

        Dir[File.join(AguiHelper::ROOT, "vectors", "apply--*.json")].each do |path|
          file = File.basename(path, ".json")
          JSON.parse(File.read(path)).fetch("vectors").each_with_index do |vector, index|
            key = "#{file}:#{vector["line"]}:#{vector["name"]}"
            define_method("test_#{file.tr("-.", "__")}_#{index}") do
              found = self.class.misses(vector, self.class.replay(vector))
              if DIVERGENCES.key?(key)
                refute_empty found, "#{key} passes now (#{DIVERGENCES[key]}): drop it from DIVERGENCES"
              else
                assert_empty found, "#{key}\n  #{vector["spec"]}"
              end
            end
          end
        end
      end
    end
  end
end
