# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # Streams captured from real AG-UI producers (test/fixtures/agui/1.0/streams:
      # the scripted starter, LangGraph, Strands with chunks, the A2UI and MCP
      # Apps middlewares, a Ruby server), each read by the SSE parser and run
      # through a strict Pipeline into a Transcript. The reference verifier
      # accepts every non-empty one, so Poetry must too: no rejection, no
      # warning, nothing the Transcript cannot apply.
      class RealStreamsTest < Minitest::Test
        Dir[File.join(AguiHelper::ROOT, "streams", "*.sse")].each do |path|
          name = File.basename(path, ".sse")
          define_method("test_#{name.tr("-", "_")}") do
            parser = SSE::Parser.new
            events = []
            parser.feed(File.read(path)) { |event| events << event }
            parser.finish { |event| events << event }

            assert_empty parser.errors, "#{name}: every frame decodes"
            skip "#{name}: the producer refused the request, so the stream is empty" if events.empty?

            transcript_warnings = []
            transcript = Transcript.new(on_warning: ->(warning) { transcript_warnings << warning.message })
            outcome = AguiHelper.run_pipeline(events)
            outcome[:events].each { |event| transcript.apply(event) }

            assert_nil outcome[:error], "#{name}: rejected - #{outcome[:error]&.message}"
            if name.include?("interrupt_default")
              # LangGraph's default signals interrupts the pre-1.0 way, and the run stalls: named, once.
              assert_equal 1, outcome[:warnings].size, name
              assert_includes outcome[:warnings].first, "on_interrupt"
            else
              assert_empty outcome[:warnings], name
            end

            assert_empty transcript_warnings, name
            refute_empty transcript.runs, name
          end
        end
      end
    end
  end
end
