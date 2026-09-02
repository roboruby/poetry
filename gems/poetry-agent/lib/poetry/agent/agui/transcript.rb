# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # Folds an AG-UI event stream into what a chat page renders: the
      # messages in order, each assistant message as Chat-shaped parts
      # (`{kind: :text, text:}`, `{kind: :reasoning, text:}`,
      # `{kind: :tool, name:, input:, output:, state:, tool_call_id:}`),
      # the shared state (snapshots and JSON Patch deltas), activities,
      # the run's status, its interrupts, and the tool calls the browser
      # must execute before the next run.
      #
      # Every change bumps {#version}, and {#apply} answers the ids of the
      # messages it touched, so a relay re-renders exactly those rows with
      # a monotonic version the page's versioned replace honors.
      class Transcript
        # One message. `role` is the protocol's ("user", "assistant",
        # "tool", "activity", ...); `parts` is the render-ready list.
        Message = Struct.new(:id, :role, :parts, :version, keyword_init: true)

        # The messages in arrival order.
        #
        # @return [Array<Message>]
        attr_reader :messages

        # The shared state after the last snapshot / delta.
        #
        # @return [Hash]
        attr_reader :state

        # Activities by message id: `{ "type" => ..., "content" => ... }`.
        #
        # @return [Hash{String => Hash}]
        attr_reader :activities

        # The run: `{ thread_id:, run_id:, status:, interrupts:, error:, result: }`;
        # status is :idle, :running, :finished, :interrupted, or :error.
        #
        # @return [Hash]
        attr_reader :run

        # The frontend-defined tool names the browser executes.
        #
        # @return [Array<String>]
        attr_reader :client_tools

        # Tool calls to client tools awaiting execution:
        # `{ tool_call_id:, name:, input:, message_id: }`.
        #
        # @return [Array<Hash>]
        attr_reader :pending_client_tools

        # RAW and CUSTOM events, in order.
        #
        # @return [Array<Hash>]
        attr_reader :custom_events

        # Event types this transcript did not understand.
        #
        # @return [Array<String>]
        attr_reader :unknown_events

        # A monotonic clock over every applied change.
        #
        # @return [Integer]
        attr_reader :version

        # @param client_tools [Array<String>] names of tools the browser executes
        def initialize(client_tools: [])
          @client_tools = client_tools.map(&:to_s)
          @messages = []
          @state = {}
          @activities = {}
          @run = { status: :idle, interrupts: [] }
          @pending_client_tools = []
          @custom_events = []
          @unknown_events = []
          @steps = []
          @version = 0
          @open_text = {}
          @tool_parts = {}
          @tool_args = {}
          @current_message_id = nil
        end

        # Applies one event.
        #
        # @param event [Hash] an AG-UI event (camelCase or snake_case keys)
        # @return [Array<String>] the ids of the messages this event changed
        def apply(event)
          type = AGUI.field(event, "type").to_s
          handler = HANDLERS[type]
          unless handler
            @unknown_events << type
            return []
          end

          Array(send(handler, event)).compact
        end

        # Applies every event of a stream.
        #
        # @param events [#each] event hashes
        # @return [self]
        def apply_all(events)
          events.each { |event| apply(event) }
          self
        end

        # @param id [String]
        # @return [Message, nil]
        def message(id)
          @messages.find { |message| message.id == id }
        end

        # The render-ready frame of one message.
        #
        # @param id [String]
        # @return [Hash] `{ parts:, version: }`
        def frame(id)
          found = message(id)
          found ? { parts: found.parts.map(&:dup), version: found.version } : { parts: [], version: 0 }
        end

        # @return [Boolean] the run ended (finished, interrupted, or errored)
        def ended?
          %i[finished interrupted error].include?(@run[:status])
        end

        # @return [Boolean]
        def interrupted?
          @run[:status] == :interrupted
        end

        # The open interrupts (string-keyed hashes as on the wire).
        #
        # @return [Array<Hash>]
        def interrupts
          @run[:interrupts]
        end

        # The run error, if any: `{ message:, code: }`.
        #
        # @return [Hash, nil]
        def error
          @run[:error]
        end

        # The messages as the next run's `RunAgentInput.messages`: user
        # and assistant messages (assistant tool calls in the protocol's
        # `toolCalls` shape) and a tool message for every finished tool
        # call; reasoning and activities stay client-side, as the
        # protocol says.
        #
        # @return [Array<Hash>]
        def messages_for_input
          @messages.flat_map do |message|
            case message.role
            when "user" then [{ "id" => message.id, "role" => "user", "content" => text_of(message) }]
            when "assistant" then assistant_wire(message)
            else []
            end
          end
        end

        # Marks a client tool call as executed and records its result, so
        # the next run's input carries the tool message.
        #
        # @param tool_call_id [String]
        # @param content [Object] the result (a string, or data serialized as JSON)
        # @param error [String, nil]
        # @return [String, nil] the id of the message that changed
        def resolve_client_tool(tool_call_id, content, error: nil)
          part = @tool_parts[tool_call_id]
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == tool_call_id }
          return nil unless part

          part[:output] = error ? { "error" => error } : parse_json(content)
          part[:state] = error ? :error : :done
          touch(part[:message_id])
        end

        private

        HANDLERS = {
          "RUN_STARTED" => :run_started, "RUN_FINISHED" => :run_finished, "RUN_ERROR" => :run_error,
          "STEP_STARTED" => :step, "STEP_FINISHED" => :step,
          "TEXT_MESSAGE_START" => :text_start, "TEXT_MESSAGE_CONTENT" => :text_content,
          "TEXT_MESSAGE_END" => :text_end, "TEXT_MESSAGE_CHUNK" => :text_chunk,
          "REASONING_MESSAGE_START" => :reasoning_start, "REASONING_MESSAGE_CONTENT" => :reasoning_content,
          "REASONING_MESSAGE_END" => :reasoning_end, "REASONING_MESSAGE_CHUNK" => :reasoning_chunk,
          "THINKING_TEXT_MESSAGE_START" => :reasoning_start, "THINKING_TEXT_MESSAGE_CONTENT" => :reasoning_content,
          "THINKING_TEXT_MESSAGE_END" => :reasoning_end,
          "REASONING_START" => :noop, "REASONING_END" => :noop, "REASONING_ENCRYPTED_VALUE" => :noop,
          "THINKING_START" => :noop, "THINKING_END" => :noop,
          "TOOL_CALL_START" => :tool_start, "TOOL_CALL_ARGS" => :tool_args, "TOOL_CALL_END" => :tool_end,
          "TOOL_CALL_CHUNK" => :tool_chunk, "TOOL_CALL_RESULT" => :tool_result,
          "STATE_SNAPSHOT" => :state_snapshot, "STATE_DELTA" => :state_delta,
          "MESSAGES_SNAPSHOT" => :messages_snapshot,
          "ACTIVITY_SNAPSHOT" => :activity_snapshot, "ACTIVITY_DELTA" => :activity_delta,
          "SUBAGENT_STARTED" => :noop, "SUBAGENT_FINISHED" => :noop, "SUBAGENT_ERROR" => :noop,
          "RAW" => :custom, "CUSTOM" => :custom
        }.freeze
        private_constant :HANDLERS

        def f(event, name) = AGUI.field(event, name)

        def noop(_event) = []

        def custom(event)
          @custom_events << event
          []
        end

        def step(event)
          @steps << [f(event, "type"), f(event, "stepName")]
          []
        end

        # --- run lifecycle ---

        def run_started(event)
          @run = { thread_id: f(event, "threadId"), run_id: f(event, "runId"), parent_run_id: f(event, "parentRunId"),
                   status: :running, interrupts: [], error: nil, result: nil }
          @version += 1
          []
        end

        def run_finished(event)
          outcome = f(event, "outcome")
          interrupts = if outcome.is_a?(Hash) && AGUI.field(outcome,
                                                            "type").to_s == "interrupt"
                         Array(AGUI.field(outcome,
                                          "interrupts"))
                       else
                         []
                       end
          @run[:interrupts] = interrupts.map { |interrupt| stringify(interrupt) }
          @run[:result] = f(event, "result")
          @run[:status] = interrupts.any? ? :interrupted : :finished
          @version += 1
          close_open_texts
        end

        def run_error(event)
          @run[:status] = :error
          @run[:error] = { message: f(event, "message").to_s, code: f(event, "code") }
          @version += 1
          close_open_texts
        end

        # --- text and reasoning ---

        def text_start(event) = start_part(f(event, "messageId"), f(event, "role") || "assistant", :text)
        def text_content(event) = append_part(f(event, "messageId"), :text, f(event, "delta"))
        def text_end(event) = end_part(f(event, "messageId"), :text)
        def reasoning_start(event) = start_part(f(event, "messageId"), "assistant", :reasoning)
        def reasoning_content(event) = append_part(f(event, "messageId"), :reasoning, f(event, "delta"))
        def reasoning_end(event) = end_part(f(event, "messageId"), :reasoning)

        def text_chunk(event) = chunk(event, :text, f(event, "role") || "assistant")
        def reasoning_chunk(event) = chunk(event, :reasoning, "assistant")

        def chunk(event, kind, role)
          id = f(event, "messageId") || @current_message_id
          return [] unless id

          changed = @open_text.key?([id, kind]) ? [] : start_part(id, role, kind)
          delta = f(event, "delta")
          changed |= append_part(id, kind, delta) if delta && !delta.empty?
          changed
        end

        def start_part(id, role, kind)
          return [] unless id

          message = ensure_message(id, role)
          part = { kind: kind, text: +"" }
          message.parts << part
          @open_text[[id, kind]] = part
          @current_message_id = id
          [touch(id)]
        end

        def append_part(id, kind, delta)
          id ||= @current_message_id
          return [] unless id && delta

          part = @open_text[[id, kind]]
          unless part
            ensure_message(id, "assistant")
            part = { kind: kind, text: +"" }
            message(id).parts << part
            @open_text[[id, kind]] = part
          end
          part[:text] = part[:text] + delta.to_s
          [touch(id)]
        end

        def end_part(id, kind)
          @open_text.delete([id || @current_message_id, kind])
          []
        end

        # A run's end closes streaming text and settles chunked tool calls
        # that never saw an END event.
        def close_open_texts
          @open_text.clear
          @tool_args.each_key do |tool_call_id|
            part = @tool_parts[tool_call_id]
            next unless part && part[:input].nil?

            part[:input] = parse_json(@tool_args[tool_call_id].to_s)
          end
          []
        end

        # --- tool calls ---

        def tool_start(event)
          tool_call_id = f(event, "toolCallId").to_s
          name = f(event, "toolCallName").to_s
          message_id = f(event, "parentMessageId") || @current_message_id || "message-#{tool_call_id}"
          ensure_message(message_id, "assistant")
          part = { kind: :tool, name: name, input: nil, output: nil, state: :loading,
                   tool_call_id: tool_call_id, message_id: message_id }
          message(message_id).parts << part
          @tool_parts[tool_call_id] = part
          @tool_args[tool_call_id] = +""
          @current_message_id = message_id
          [touch(message_id)]
        end

        def tool_args(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          @tool_args[tool_call_id] << f(event, "delta").to_s
          [touch(part[:message_id])]
        end

        def tool_end(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          part[:input] = parse_json(@tool_args.delete(tool_call_id).to_s)
          if @client_tools.include?(part[:name])
            part[:state] = :awaiting_client
            @pending_client_tools << { tool_call_id: tool_call_id, name: part[:name], input: part[:input],
                                       message_id: part[:message_id] }
          end
          [touch(part[:message_id])]
        end

        def tool_chunk(event)
          tool_call_id = f(event, "toolCallId")
          changed = []
          changed |= tool_start(event) if tool_call_id && !@tool_parts.key?(tool_call_id.to_s)
          delta = f(event, "delta")
          id = (tool_call_id || @tool_parts.keys.last).to_s
          changed |= tool_args({ "toolCallId" => id, "delta" => delta }) if delta
          # A chunked call has no END event: its input is whatever has parsed so far.
          part = @tool_parts[id]
          if part && (parsed = parse_json(@tool_args[id].to_s)).is_a?(Hash)
            part[:input] = parsed
          end
          changed
        end

        def tool_result(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          part[:input] ||= parse_json(@tool_args.delete(tool_call_id).to_s) if @tool_args.key?(tool_call_id)
          part[:output] = parse_json(f(event, "content"))
          part[:state] = :done
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == tool_call_id }
          [touch(part[:message_id])]
        end

        # --- state, messages, activities ---

        def state_snapshot(event)
          @state = JsonPatch.deep_copy(f(event, "snapshot") || {})
          @version += 1
          []
        end

        def state_delta(event)
          @state = JsonPatch.apply(@state, f(event, "delta") || [])
          @version += 1
          []
        rescue JsonPatch::Error => e
          @unknown_events << "STATE_DELTA(#{e.message})"
          []
        end

        def messages_snapshot(event)
          rebuilt = Array(f(event, "messages")).filter_map { |message| snapshot_message(stringify(message)) }
          @messages = rebuilt
          @open_text.clear
          @version += 1
          @messages.each { |message| message.version = @version }
          @messages.map(&:id)
        end

        # One snapshot message as a Message - or nil for a tool result, which
        # lands on its call's part instead.
        def snapshot_message(wire)
          id = wire["id"].to_s
          case wire["role"].to_s
          when "user", "system", "developer"
            Message.new(id: id, role: wire["role"].to_s, parts: [{ kind: :text, text: wire["content"].to_s }],
                        version: 0)
          when "assistant" then snapshot_assistant(wire)
          when "tool" then snapshot_tool_result(wire)
          when "activity"
            part = { kind: :activity, activity_type: wire["activityType"], content: wire["content"] }
            Message.new(id: id, role: "activity", parts: [part], version: 0)
          when "reasoning"
            Message.new(id: id, role: "assistant", parts: [{ kind: :reasoning, text: wire["content"].to_s }],
                        version: 0)
          end
        end

        def snapshot_assistant(wire)
          parts = []
          parts << { kind: :text, text: wire["content"] } if wire["content"].is_a?(String) && !wire["content"].empty?
          Array(wire["toolCalls"]).each do |call|
            function = call["function"] || {}
            part = { kind: :tool, name: function["name"].to_s, input: parse_json(function["arguments"]),
                     output: nil, state: :loading, tool_call_id: call["id"].to_s, message_id: wire["id"].to_s }
            parts << part
            @tool_parts[part[:tool_call_id]] = part
          end
          Message.new(id: wire["id"].to_s, role: "assistant", parts: parts, version: 0)
        end

        def snapshot_tool_result(wire)
          part = @tool_parts[wire["toolCallId"].to_s]
          return nil unless part

          part[:output] = wire["error"] ? { "error" => wire["error"] } : parse_json(wire["content"])
          part[:state] = wire["error"] ? :error : :done
          nil
        end

        def activity_snapshot(event)
          id = f(event, "messageId").to_s
          replace = f(event, "replace")
          return [] if replace == false && @activities.key?(id)

          @activities[id] =
            { "type" => f(event, "activityType"), "content" => JsonPatch.deep_copy(f(event, "content")) }
          message = ensure_message(id, "activity")
          message.parts = [{ kind: :activity, activity_type: @activities[id]["type"],
                             content: @activities[id]["content"] }]
          [touch(id)]
        end

        def activity_delta(event)
          id = f(event, "messageId").to_s
          activity = @activities[id]
          return [] unless activity

          activity["content"] = JsonPatch.apply(activity["content"], f(event, "patch") || [])
          message(id).parts = [{ kind: :activity, activity_type: activity["type"], content: activity["content"] }]
          [touch(id)]
        rescue JsonPatch::Error => e
          @unknown_events << "ACTIVITY_DELTA(#{e.message})"
          []
        end

        # --- helpers ---

        def ensure_message(id, role)
          id = id.to_s
          message(id) || Message.new(id: id, role: role.to_s, parts: [], version: 0).tap do |created|
            @messages << created
          end
        end

        def touch(id)
          @version += 1
          found = message(id)
          found.version = @version if found
          id
        end

        def text_of(message)
          message.parts.select { |part| part[:kind] == :text }.map { |part| part[:text] }.join
        end

        def assistant_wire(message)
          wire = { "id" => message.id, "role" => "assistant", "content" => text_of(message) }
          calls = message.parts.select { |part| part[:kind] == :tool }
          if calls.any?
            wire["toolCalls"] = calls.map do |part|
              { "id" => part[:tool_call_id], "type" => "function",
                "function" => { "name" => part[:name], "arguments" => JSON.generate(part[:input] || {}) } }
            end
          end
          results = calls.reject { |part| part[:output].nil? }.map do |part|
            error = part[:output].is_a?(Hash) ? part[:output]["error"] : nil
            RunInput.tool_message(part[:tool_call_id], error || as_text(part[:output]),
                                  error: error, id: "#{part[:tool_call_id]}-result")
          end
          [wire, *results]
        end

        def as_text(value)
          value.is_a?(String) ? value : JSON.generate(value)
        end

        def parse_json(text)
          return text unless text.is_a?(String)
          return text if text.empty?

          JSON.parse(text)
        rescue JSON::ParserError
          text
        end

        def stringify(value)
          case value
          when Hash then value.to_h { |key, inner| [key.to_s, stringify(inner)] }
          when Array then value.map { |inner| stringify(inner) }
          else value
          end
        end
      end
    end
  end
end
