# frozen_string_literal: true

require "base64"

# The AG-UI relay's rows for the states the scripted demo does not reach:
# attachments on a user's turn, a tool result made of content parts, a
# frontend call the person declined, a subagent that failed, a run the
# agent cancelled, and a stream the page stopped reading. Each is a real
# AG-UI 1.0 event stream through a strict Pipeline into a Transcript, so
# the rows are what a host holds.
module Poetry
  module Docs
    module AguiStates
      # One state: a title, a line on what it shows, and its transcript.
      State = Struct.new(:id, :title, :note, :transcript, keyword_init: true)

      # A small seat chart, inline, so every part is keyless and offline.
      CHART = Base64.strict_encode64(<<~SVG)
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80"><rect width="120" height="80" fill="#f4f4f5"/><rect x="14" y="44" width="18" height="24" fill="#a1a1aa"/><rect x="42" y="28" width="18" height="40" fill="#71717a"/><rect x="70" y="16" width="18" height="52" fill="#3f3f46"/><rect x="98" y="36" width="10" height="32" fill="#a1a1aa"/></svg>
      SVG
      ROSTER = Base64.strict_encode64("name,seat\nAda,1\nGrace,2\n")

      module_function

      # Every state, in the order the page shows them.
      #
      # @return [Array<State>]
      def all
        [ attachments, tool_parts, declined, failed_subagent, cancelled, truncated ]
      end

      def attachments
        transcript = Poetry::Agent::AGUI::Transcript.new
        transcript.add_message(Poetry::Agent::AGUI::RunInput.user_message([
          { "type" => "text", "text" => "Here's our seat chart and the roster. Which plan fits?" },
          { "type" => "image", "source" => { "type" => "data", "value" => CHART, "mimeType" => "image/svg+xml" },
            "metadata" => { "filename" => "seat-chart.svg" } },
          { "type" => "document", "source" => { "type" => "data", "value" => ROSTER, "mimeType" => "text/csv" },
            "metadata" => { "filename" => "roster.csv" } }
        ], id: "s1-u"))
        replay(transcript, [ start, *text("s1-a", "Ten seats on the chart: the Team plan fits."), finish ])
        State.new(id: "attachments", title: "A turn with attachments",
                  note: "Images and documents on a user's turn are content parts; the row shows them as Attachment chips.",
                  transcript: transcript)
      end

      def tool_parts
        transcript = Poetry::Agent::AGUI::Transcript.new
        replay(transcript, [
          start, *call("s2-c", "render_seat_chart", "s2-a", '{"seats":10}'),
          { "type" => "TOOL_CALL_RESULT", "messageId" => "s2-t", "toolCallId" => "s2-c", "content" => [
            { "type" => "text", "text" => "Ten seats across four rows." },
            { "type" => "image", "source" => { "type" => "data", "value" => CHART, "mimeType" => "image/svg+xml" },
              "metadata" => { "filename" => "chart.svg" } }
          ] },
          finish
        ])
        State.new(id: "tool-parts", title: "A tool result made of parts",
                  note: "A result's text is its Output; its images open beside it, never base64 in a code block.",
                  transcript: transcript)
      end

      def declined
        transcript = Poetry::Agent::AGUI::Transcript.new(client_tools: [ { name: AguiReplay::CLIENT_TOOL, confirm: true } ])
        replay(transcript, [ start, *call("s3-c", AguiReplay::CLIENT_TOOL, "s3-a", '{"value":"pricing"}'), finish ])
        transcript.decline_client_tool("s3-c")
        State.new(id: "declined", title: "A call the person declined",
                  note: "A tool that asks first never runs on a Deny: the agent is told it was declined.",
                  transcript: transcript)
      end

      def failed_subagent
        transcript = Poetry::Agent::AGUI::Transcript.new
        replay(transcript, [
          start,
          { "type" => "SUBAGENT_STARTED", "subagentRunId" => "s4-sub", "name" => "research" },
          *call("s4-c", "lookup_plans", "s4-sub-a", '{"seats":10}').each { |event| event["subagentRunId"] = "s4-sub" },
          { "type" => "SUBAGENT_ERROR", "subagentRunId" => "s4-sub", "message" => "The plans service timed out." },
          *text("s4-a", "The research subagent couldn't reach the plans service; try again in a minute."),
          finish
        ])
        State.new(id: "failed-subagent", title: "A subagent that failed",
                  note: "A subagent's work nests under a step naming it; its failure ends the invocation, not the run.",
                  transcript: transcript)
      end

      def cancelled
        transcript = Poetry::Agent::AGUI::Transcript.new
        replay(transcript, [
          start, *call("s5-c", "lookup_plans", "s5-a", '{"seats":10}'),
          { "type" => "RUN_FINISHED", "threadId" => "states", "runId" => "r", "outcome" => { "type" => "cancelled" } }
        ])
        State.new(id: "cancelled", title: "A run the agent cancelled",
                  note: "A cancelled run is neither success nor failure: what waited reads stopped.",
                  transcript: transcript)
      end

      def truncated
        transcript = Poetry::Agent::AGUI::Transcript.new
        replay(transcript, [ start, *text("s6-a", "Team is $12 a seat, so for ten").first(2) ])
        transcript.truncate
        State.new(id: "truncated", title: "A stream the page stopped reading",
                  note: "Breaking off a stream invents no ending: Transcript#truncate marks the run truncated.",
                  transcript: transcript)
      end

      # Events through a strict pipeline into the transcript.
      def replay(transcript, events)
        pipeline = Poetry::Agent::AGUI::Pipeline.new
        events.each { |event| pipeline.push(event).each { |verified| transcript.apply(verified) } }
        transcript
      end

      def start = { "type" => "RUN_STARTED", "threadId" => "states", "runId" => "r" }
      def finish = { "type" => "RUN_FINISHED", "threadId" => "states", "runId" => "r" }

      def text(id, sentence)
        [ { "type" => "TEXT_MESSAGE_START", "messageId" => id, "role" => "assistant" },
          { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => id, "delta" => sentence },
          { "type" => "TEXT_MESSAGE_END", "messageId" => id } ]
      end

      def call(id, name, parent, arguments)
        [ { "type" => "TOOL_CALL_START", "toolCallId" => id, "toolCallName" => name, "parentMessageId" => parent },
          { "type" => "TOOL_CALL_ARGS", "toolCallId" => id, "delta" => arguments },
          { "type" => "TOOL_CALL_END", "toolCallId" => id } ]
      end

      private_class_method :attachments, :tool_parts, :declined, :failed_subagent, :cancelled, :truncated, :replay,
                           :start, :finish, :text, :call
    end
  end
end
