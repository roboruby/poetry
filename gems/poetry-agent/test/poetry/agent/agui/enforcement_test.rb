# frozen_string_literal: true

require "test_helper"
require "json_schemer"

module Poetry
  module Agent
    module AGUI
      # AG-UI 1.0 enforcement against the schema's own per-definition
      # fixtures (test/fixtures/agui/1.0/fixtures): a valid document comes back
      # untouched, an invalid one raises - unless the processing rule strips it
      # (an unknown property or union member), in which case exactly the stated
      # paths go. Every value the walker returns must validate against its
      # definition's anchor (json_schemer, test-only).
      class EnforcementTest < Minitest::Test
        ROOT = File.expand_path("../../../fixtures/agui/1.0", __dir__)

        # The invalid fixtures a receiver strips rather than rejects, and the
        # paths it strips. The expect files are written for a validator, which
        # rejects unknown material outright; which of them a receiver strips is
        # the processing rule's call, so this table is written from the
        # documents.
        # Invalid fixtures that pin the reference's admitted closed-set gap: a
        # required field holding a string its closed set does not name. The
        # spec (processing.mdx, reasoning.mdx) makes that unrecognised material,
        # which in a required position removes the value carrying it.
        DROP_CASES = {
          "ReasoningEncryptedValueEvent/unknown-subtype" => "/subtype",
          "ResumeEntry/unknown-status" => "/status"
        }.freeze

        STRIP_CASES = {
          "AgentCapabilities/old-subagents-key" => ["/multiAgent/subAgents"],
          "FileSource/reference-record" => ["/reference"],
          "MultiAgentCapabilities/old-subagents-key" => ["/subAgents"],
          "TextMessageEndEvent/unknown-property" => ["/somethingNewer"],
          "RunFinishedEvent/outcome-cancelled-carrying-interrupts" => ["/outcome/interrupts"],
          "RunFinishedEvent/outcome-interrupt-carrying-pending-tool-call-ids" => ["/outcome/pendingToolCallIds"],
          "RunFinishedEvent/outcome-success-carrying-interrupts" => ["/outcome/interrupts"],
          "SubagentFinishedEvent/outcome-success-carrying-interrupt-ids" => ["/outcome/interruptIds"],
          "MessagesSnapshotEvent/unknown-role" => ["/messages/0"],
          "MessagesSnapshotEvent/role-shaped-like-a-tool-message" => ["/messages/0"],
          "MessagesSnapshotEvent/role-shaped-like-an-activity-message" => ["/messages/0"],
          "MessagesSnapshotEvent/role-shaped-like-an-assistant-message" => ["/messages/0"],
          "ToolCallResultEvent/content-part-unknown-type" => ["/content/0"],
          "ToolMessage/content-part-unknown-type" => ["/content/0"],
          "UserMessage/legacy-binary-part" => ["/content/0"],
          "UserMessage/part-shaped-like-media-with-unknown-type" => ["/content/0"],
          "UserMessage/part-shaped-like-text-with-unknown-type" => ["/content/0"],
          "StateDeltaEvent/patch-unknown-op" => ["/delta/0"]
        }.freeze

        # Cases the upstream fixtures cannot express for a Ruby receiver
        # (Ruby parses 1.0 as a Float, and its ^ and $ anchor lines), plus the
        # reference's strip unit cases: [label, anchor, document, expectation],
        # the expectation :pass, [:strip, paths] or [:raise, keyword].
        EXTRAS = [
          ["zero-fraction float timestamp is an integer", "TextMessageEndEvent",
           { "type" => "TEXT_MESSAGE_END", "messageId" => "m", "timestamp" => 1_700_000_000_000.0 }, :pass],
          ["zero-fraction float past the safe maximum", "TextMessageEndEvent",
           { "type" => "TEXT_MESSAGE_END", "messageId" => "m", "timestamp" => 9_007_199_254_740_992.0 },
           [:raise, "maximum"]],
          ["pointer with a newline before a slash (Ruby ^ would accept it)", "StateDeltaEvent",
           { "type" => "STATE_DELTA", "delta" => [{ "op" => "remove", "path" => "x\n/a" }] }, [:raise, "pattern"]],
          ["pointer whose token holds a newline", "StateDeltaEvent",
           { "type" => "STATE_DELTA", "delta" => [{ "op" => "remove", "path" => "/a\nb" }] }, :pass],
          ["unknown source kind removes the part; nothing inside it is reported", "MessagesSnapshotEvent",
           { "type" => "MESSAGES_SNAPSHOT",
             "messages" => [{ "id" => "m1", "role" => "user", "junkTop" => 1,
                              "content" => [{ "type" => "image", "junk" => 2,
                                              "source" => { "type" => "future" } }] }] },
           [:strip, ["/messages/0/junkTop", "/messages/0/content/0"]]],
          ["a malformed field inside a part that is removed anyway is not fatal", "UserMessage",
           { "id" => "m1", "role" => "user",
             "content" => [{ "type" => "image", "id" => 42, "source" => { "type" => "future" } }] },
           [:strip, ["/content/0"]]],
          ["an array in a union slot is fatal", "RunFinishedEvent",
           { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r", "outcome" => [{ "type" => "cancelled" }] },
           [:raise, "oneOf"]],
          ["a string in a union slot is fatal", "RunFinishedEvent",
           { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r", "outcome" => "success" }, [:raise, "oneOf"]],
          ["unknown outcome kind leaves its optional slot", "RunFinishedEvent",
           { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r", "outcome" => { "type" => "deferred" } },
           [:strip, ["/outcome"]]],
          ["patch operation extras are preserved", "StateDeltaEvent",
           { "type" => "STATE_DELTA", "delta" => [{ "op" => "remove", "path" => "/a", "value" => 1, "note" => "x" }] },
           :pass],
          ["open metadata keeps nulls and nested shapes", "TextMessageContentEvent",
           { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m", "delta" => "",
             "metadata" => { "a" => nil, "ag-ui" => { "x" => [1] } } }, :pass],
          ["prototype-named keys are stripped like any other", "TextMessageStartEvent",
           { "type" => "TEXT_MESSAGE_START", "messageId" => "m", "toString" => 1, "constructor" => 2 },
           [:strip, ["/toString", "/constructor"]]],
          ["a key needing pointer escapes", "TextMessageEndEvent",
           { "type" => "TEXT_MESSAGE_END", "messageId" => "m", "a/b~c" => 1 }, [:strip, ["/a~1b~0c"]]],
          ["a missing union tag drops the element", "MessagesSnapshotEvent",
           { "type" => "MESSAGES_SNAPSHOT", "messages" => [{ "id" => "1", "content" => "x" }] },
           [:strip, ["/messages/0"]]],
          ["a non-string union tag drops the element", "MessagesSnapshotEvent",
           { "type" => "MESSAGES_SNAPSHOT", "messages" => [{ "id" => "1", "role" => 42, "content" => "x" }] },
           [:strip, ["/messages/0"]]],
          ["a role outside TextMessageRole is stripped, a member of a closed set added later", "TextMessageStartEvent",
           { "type" => "TEXT_MESSAGE_START", "messageId" => "m", "role" => "narrator" }, [:strip, ["/role"]]],
          ["a role that is not a string is still malformed, not unrecognised", "TextMessageStartEvent",
           { "type" => "TEXT_MESSAGE_START", "messageId" => "m", "role" => 7 }, [:raise, "type"]],
          ["responseSchema true (a boolean JSON Schema) is fatal", "Interrupt",
           { "id" => "i", "reason" => "r", "responseSchema" => true }, [:raise, "type"]],
          ["an unknown key on an interrupt is stripped inside its list", "RunFinishedEvent",
           { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r",
             "outcome" => { "type" => "interrupt", "interrupts" => [{ "id" => "i", "reason" => "r", "junk" => 1 }] } },
           [:strip, ["/outcome/interrupts/0/junk"]]]
        ].freeze

        def self.schemer
          @schemer ||= JSONSchemer.schema(JSON.parse(File.read(File.join(ROOT, "schema.json"))),
                                          regexp_resolver: "ecma")
        end

        def self.anchor(name) = (@anchors ||= {})[name] ||= schemer.ref("##{name}")

        def walker = Enforcement::Walker.default

        Dir[File.join(ROOT, "fixtures", "*", "{valid,invalid}", "*.json")].each do |path|
          next if path.end_with?(".expect.json")

          definition, set, file = path.delete_prefix("#{ROOT}/fixtures/").split("/")
          name = "#{definition}/#{file.delete_suffix(".json")}"
          define_method("test_fixture_#{set}_#{name.tr("/-", "__")}") do
            document = JSON.parse(File.read(path))
            if set == "valid"
              value, stripped = walker.definition(document, definition)

              assert_empty stripped, "#{name}: a valid document strips nothing"
              assert_same document, value, "#{name}: comes back untouched"
            elsif DROP_CASES.key?(name)
              assert_equal [nil, [DROP_CASES[name]]], walker.definition(document, definition), name
            elsif STRIP_CASES.key?(name)
              value, stripped = walker.definition(document, definition)

              assert_equal STRIP_CASES[name], stripped, name
              assert self.class.anchor(definition).valid?(value), "#{name}: the stripped value validates"
            else
              assert_raises(Enforcement::Malformed, name) { walker.definition(document, definition) }
            end
          end
        end

        EXTRAS.each do |label, anchor, document, expectation|
          define_method("test_ruby_case_#{label.downcase.gsub(/[^a-z0-9]+/, "_")}") do
            if expectation.is_a?(Array) && expectation.first == :raise
              error = assert_raises(Enforcement::Malformed) { walker.definition(document, anchor) }

              assert_equal expectation.last, error.keyword
            else
              value, stripped = walker.definition(document, anchor)

              assert_equal(expectation == :pass ? [] : expectation.last, stripped)
              assert_same document, value if expectation == :pass

              assert self.class.anchor(anchor).valid?(value), "#{label}: the result validates"
            end
          end
        end

        def test_an_unknown_event_is_dropped_with_a_warning_naming_it
          warnings = []

          assert_nil walker.event({ "type" => "FUTURE_EVENT", "x" => 1 }) { |warning| warnings << warning }
          assert_equal :unrecognised_event, warnings.last.kind
          assert_includes warnings.last.message, "FUTURE_EVENT"
          assert_nil walker.event({ "messageId" => "m" }), "an event with no type is dropped"
          assert_nil walker.event({ type: "TEXT_MESSAGE_END", messageId: "m" }), "symbol keys are not wire keys"
          assert_raises(Enforcement::Malformed) { walker.event([1]) }
        end

        def test_a_stripped_event_warns_once_per_path
          warnings = []
          event = walker.event({ "type" => "TEXT_MESSAGE_END", "messageId" => "m", "x" => 1 }) { |w| warnings << w }

          assert_equal({ "type" => "TEXT_MESSAGE_END", "messageId" => "m" }, event)
          assert_equal ["Removed unrecognised material at '/x' on TEXT_MESSAGE_END."], warnings.map(&:message)
        end

        def test_the_outgoing_input_reads_optional_nulls_as_absent_and_strips_the_unknown
          warnings = []
          input = walker.input({ "threadId" => "t", "runId" => "r", "messages" => [], "parentRunId" => nil,
                                 "state" => nil,
                                 "tools" => [{ "name" => "n", "description" => "d", "parameters" => nil }],
                                 "legacyFlag" => true }) { |w| warnings << w }

          assert_equal({ "threadId" => "t", "runId" => "r", "messages" => [],
                         "tools" => [{ "name" => "n", "description" => "d" }] }, input)
          assert_equal ["Removed unrecognised material at '/legacyFlag' from the outgoing input."],
                       warnings.map(&:message)
          assert_raises(Enforcement::Malformed) { walker.input({ "threadId" => nil, "runId" => "r", "messages" => [] }) }
        end

        def test_the_entry_budget_refuses_an_oversized_event
          small = Enforcement::Walker.new(walker.table, max_entries: 10)
          many = { "type" => "MESSAGES_SNAPSHOT",
                   "messages" => Array.new(20) { |i| { "id" => i.to_s, "role" => "user", "content" => "x" } } }

          assert_raises(Enforcement::LimitError) { small.event(many) }
        end

        def test_a_malformed_value_is_a_protocol_error_from_enforcement
          error = assert_raises(ProtocolError) { walker.event({ "type" => "TEXT_MESSAGE_END", "messageId" => 7 }) }

          assert_equal :enforcement, error.stage
          assert_includes error.message, "Malformed TEXT_MESSAGE_END at '/messageId'"
        end
      end
    end
  end
end
