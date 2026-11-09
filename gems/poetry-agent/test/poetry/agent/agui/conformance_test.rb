# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # AG-UI 1.0's receiver conformance corpus
      # (test/fixtures/agui/1.0/conformance/streams), each stream through a
      # strict Pipeline into a Transcript, every `expect` key scored on
      # Poetry's surfaces: delivered events are the pipeline's output,
      # warnings are the pipeline's and the transcript's, "failed" is a
      # ProtocolError, messages are messages_for_input plus activity
      # messages, the request is the pipeline's outgoing input.
      class ConformanceTest < Minitest::Test
        STREAMS = File.join(AguiHelper::ROOT, "conformance", "streams")

        # The fixture the corpus README says to relax for a third-party
        # client: it pins the reference client's admitted gap (an unknown
        # member of a closed string set, a message role, is fatal there where
        # the spec wants it stripped). Poetry strips it, as the spec says, so
        # this fixture fails as written; PipelineTest pins the stripping.
        RELAXED = %w[unknown-enum-value-role-fatal].freeze

        # Fixtures Poetry does not pass yet, each with what closes it. A
        # listed fixture that starts passing fails the suite: the list only
        # shrinks. Empty since phase 3: every scored fixture passes.
        DIVERGENCES = {}.freeze

        # A value at "<index>.<dotted path>" inside a list of events, or :absent.
        def self.dig_path(root, path)
          path.split(".").reduce(root) do |node, key|
            case node
            when Array then key.match?(/\A\d+\z/) && key.to_i < node.size ? node[key.to_i] : (return :absent)
            when Hash then node.key?(key) ? node[key] : (return :absent)
            else return :absent
            end
          end
        end

        # The corpus's subset match: arrays the same length, objects on named keys.
        def self.subset?(expected, actual)
          case expected
          when Hash then actual.is_a?(Hash) && expected.all? { |k, v| actual.key?(k) && subset?(v, actual[k]) }
          when Array
            actual.is_a?(Array) && expected.size == actual.size && expected.zip(actual).all? { |e, a| subset?(e, a) }
          else expected == actual
          end
        end

        # The transcript's messages in the wire shape, tool results and activity
        # messages where they sit.
        def self.wire_messages(transcript) = transcript.send(:stored_wire)

        # One fixture through a pipeline and a fresh transcript.
        def self.replay_fixture(fixture)
          input = fixture["input"] || {}
          warnings = []
          collect = ->(warning) { warnings << warning.message }
          transcript = Transcript.new(client_tools: Array(input["tools"]).map do |tool|
            tool["name"]
          end, on_warning: collect)
          Array(input["messages"]).each { |message| transcript.add_message(message) }
          pipeline = Pipeline.new(on_warning: collect,
                                  max_protocol_version: fixture.dig("client",
                                                                    "maxProtocolVersion"))
          delivered = []
          error = nil
          apply = lambda do |event|
            delivered << event
            transcript.apply(event)
          end
          begin
            fixture["stream"].each { |raw| pipeline.push(raw).each(&apply) }
            pipeline.finish.each(&apply)
          rescue ProtocolError => e
            error = e
            e.events.each(&apply)
          end
          request = pipeline.outgoing(RunInput.build(thread_id: "t", run_id: "r", messages: Array(input["messages"]),
                                                     tools: Array(input["tools"])))
          { delivered: delivered, error: error, warnings: warnings, transcript: transcript, request: request }
        end

        # The keys a fixture asserts, and whether each holds.
        def self.score(fixture, result)
          expect = fixture["expect"].merge(fixture.dig("expectOverrides", "typescript").to_h.except("intentional"))
          transcript = result[:transcript]
          types = result[:delivered].map { |event| event["type"] }
          checks = { "outcome" => (result[:error] ? "failed" : "completed") == expect["outcome"] }
          if expect.key?("errorContains")
            wanted = expect["errorContains"].gsub('\\"', '"') # the reference's message was JSON-escaped
            checks["errorContains"] = !result[:error].nil? && result[:error].message.include?(wanted)
          end
          if expect.key?("runError")
            errors = transcript.runs.filter_map { |run| run[:error] }
            checks["runError"] = if expect["runError"] == true
                                   errors.any?
                                 else
                                   errors.any? do |e|
                                     e[:message].include?(expect["runError"])
                                   end
                                 end
          end
          checks["eventTypes"] = types == expect["eventTypes"] if expect.key?("eventTypes")
          checks["eventTypesAbsent"] = !expect["eventTypesAbsent"].intersect?(types) if expect.key?("eventTypesAbsent")
          if expect.key?("eventPaths")
            checks["eventPaths"] = expect["eventPaths"].all? do |path, value|
              dig_path(result[:delivered], path) == value
            end
          end
          if expect.key?("eventAbsentPaths")
            checks["eventAbsentPaths"] = expect["eventAbsentPaths"].all? do |path|
              dig_path(result[:delivered], path) == :absent
            end
          end
          if expect.key?("warnings")
            checks["warnings"] = expect["warnings"].all? { |text| result[:warnings].any? { |w| w.include?(text) } }
          end
          checks["noWarnings"] = result[:warnings].empty? if expect["noWarnings"]
          messages = wire_messages(transcript)
          checks["messageCount"] = messages.size == expect["messageCount"] if expect.key?("messageCount")
          checks["messages"] = subset?(expect["messages"], messages) if expect.key?("messages")
          checks["state"] = subset?(expect["state"], transcript.state) if expect.key?("state")
          checks["request"] = subset?(expect["request"], result[:request]) if expect.key?("request")
          if expect.key?("requestAbsentPaths")
            checks["requestAbsentPaths"] = expect["requestAbsentPaths"].all? do |path|
              dig_path(result[:request], path) == :absent
            end
          end
          checks
        end

        def test_the_corpus_is_the_manifest
          listed = File.readlines(File.join(STREAMS, "MANIFEST.txt")).map(&:strip).grep(/\.json\z/)

          assert_equal listed.sort, Dir[File.join(STREAMS, "*.json")].map { |path| File.basename(path) }.sort
        end

        Dir[File.join(STREAMS, "*.json")].each do |path|
          fixture = JSON.parse(File.read(path))
          name = fixture["name"]
          next if RELAXED.include?(name)

          define_method("test_#{name.tr("-", "_")}") do
            checks = self.class.score(fixture, self.class.replay_fixture(fixture))
            failed = checks.reject { |_, ok| ok }.keys
            if DIVERGENCES.key?(name)
              refute_empty failed, "#{name} passes now (#{DIVERGENCES[name]}): drop it from DIVERGENCES"
            else
              assert_empty failed, "#{name}: #{fixture["description"]}"
            end
          end
        end
      end
    end
  end
end
