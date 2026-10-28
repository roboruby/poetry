# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # Folds an AG-UI event stream into what a chat page renders: the
      # messages in order, each as Chat-shaped parts
      # (`{kind: :text, text:, state:}`, `{kind: :reasoning, text:, state:}`,
      # `{kind: :tool, name:, input:, output:, state:, tool_call_id:}`,
      # `{kind: :media, part:}` for a non-text content part), the shared
      # state (snapshots and JSON Patch deltas), activities, every run's
      # status and interrupts, and the tool calls the browser must execute
      # before the next run. A text or reasoning part is `state: :streaming`
      # until its END event (or the run's end) closes it, then `:done` - the
      # difference between "Thinking" and "Thought". A reasoning message is
      # a message of its own (role `reasoning`), as in AG-UI 1.0.
      #
      # It reduces VERIFIED events: what a {Pipeline} delivers (Client#run and
      # Relay route the wire through one), so every chunk is already expanded,
      # every id present, and every open item closed by the stream itself. A
      # patch it cannot apply, or an activity delta with nothing to patch, is
      # a {ProtocolWarning}.
      #
      # Every change bumps {#version}, and {#apply} answers the ids of the
      # messages it touched, so a relay re-renders exactly those rows with
      # a monotonic version the page's versioned replace honors.
      class Transcript
        # One message. `role` is the protocol's ("user", "assistant",
        # "reasoning", "tool", "activity", ...); `parts` is the render-ready list.
        Message = Struct.new(:id, :role, :parts, :version, keyword_init: true)

        # The messages in arrival order.
        #
        # @return [Array<Message>]
        attr_reader :messages

        # The shared state after the last snapshot / delta: any JSON value,
        # usually a Hash.
        #
        # @return [Object]
        attr_reader :state

        # Activities by message id: `{ "type" => ..., "content" => ... }`.
        #
        # @return [Hash{String => Hash}]
        attr_reader :activities

        # The current (latest) run: `{ thread_id:, run_id:, status:, interrupts:, error:, result: }`;
        # status is :idle, :running, :finished, :interrupted, :cancelled, or :error.
        #
        # @return [Hash]
        attr_reader :run

        # Every run the stream carried, in order (each shaped like {#run}),
        # so a first run's failure survives a second run on the same stream.
        #
        # @return [Array<Hash>]
        attr_reader :runs

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

        # What this transcript could not apply (a failed patch, an activity
        # delta naming no activity), in order.
        #
        # @return [Array<ProtocolWarning>]
        attr_reader :warnings

        # A monotonic clock over every applied change.
        #
        # @return [Integer]
        attr_reader :version

        # An empty transcript, with the client-side tool names.
        # @param client_tools [Array<String>] names of tools the browser executes
        # @param on_warning [#call, nil] receives each {ProtocolWarning} as it happens
        def initialize(client_tools: [], on_warning: nil)
          @client_tools = client_tools.map(&:to_s)
          @messages = []
          @state = {}
          @activities = {}
          @run = { status: :idle, interrupts: [] }
          @runs = []
          @pending_client_tools = []
          @custom_events = []
          @warnings = []
          @on_warning = on_warning
          @steps = []
          @version = 0
          @open_text = {}
          @tool_parts = {}
          @tool_args = {}
        end

        # Applies one verified event.
        #
        # @param event [Hash] an event a {Pipeline} delivered
        # @return [Array<String>] the ids of the messages this event changed (dropped ones included)
        # @raise [ArgumentError] for a type a pipeline never delivers (a chunk, a retired THINKING_* event)
        def apply(event)
          handler = HANDLERS[event["type"]]
          unless handler
            raise ArgumentError, "Transcript#apply takes verified events; #{event["type"].inspect} reaches it only " \
                                 "unprocessed - route the stream through a Poetry::Agent::AGUI::Pipeline"
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

        # A message by id, or nil.
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

        # Whether the run finished, was interrupted, was cancelled, or failed.
        # @return [Boolean] the run ended; false for a stream that broke off before its terminal event
        def ended?
          %i[finished interrupted cancelled error].include?(@run[:status])
        end

        # Whether the run was interrupted.
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

        # The current run's error, if any: `{ message:, code: }`.
        #
        # @return [Hash, nil]
        def error
          @run[:error]
        end

        # The messages as the next run's `RunAgentInput.messages`: user,
        # system and developer messages (content parts kept as parts),
        # assistant messages with their tool calls (arguments exactly as they
        # streamed), reasoning messages, and a tool message for every
        # answered call under the result's own id. Activity messages stay
        # client-side: the protocol requires stripping them.
        #
        # @return [Array<Hash>]
        def messages_for_input
          @messages.flat_map do |message|
            case message.role
            when "user", "system", "developer"
              [{ "id" => message.id, "role" => message.role, "content" => content_of(message) }]
            when "assistant" then assistant_wire(message)
            when "reasoning" then [{ "id" => message.id, "role" => "reasoning", "content" => reasoning_of(message) }]
            else []
            end
          end
        end

        # Records a message the host itself sends - its user turn, a tool
        # result, a system prompt - so {#messages_for_input} carries the whole
        # conversation (no event ever echoes it) and a relay can render it. A
        # tool message lands on the call it answers.
        #
        # @param wire [Hash] a protocol message ({RunInput.user_message}, {RunInput.tool_message}, ...)
        # @return [Array<String>] the ids of the messages that changed
        # @example The user's turn, before the run that answers it
        #   user = RunInput.user_message(params[:q])
        #   transcript.add_message(user)
        #   RunInput.build(thread_id: thread, messages: transcript.messages_for_input)
        def add_message(wire)
          wire = stringify(wire)
          if wire["role"].to_s == "tool"
            snapshot_tool_result(wire)
            part = @tool_parts[wire["toolCallId"].to_s]
            @pending_client_tools.reject! { |pending| pending[:tool_call_id] == wire["toolCallId"].to_s }
            return part ? [touch(part[:message_id])] : []
          end

          added = snapshot_message(wire)
          return [] unless added

          index = @messages.index { |message| message.id == added.id }
          index ? @messages[index] = added : @messages << added
          [touch(added.id)]
        end

        # Marks a client tool call as executed and records its result, so
        # the next run's input carries the tool message.
        #
        # @param tool_call_id [String]
        # @param content [Object] the result (a string, content parts, or data serialized as JSON)
        # @param error [String, nil]
        # @return [String, nil] the id of the message that changed
        def resolve_client_tool(tool_call_id, content, error: nil)
          part = @tool_parts[tool_call_id]
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == tool_call_id }
          return nil unless part

          part[:output] = error ? { "error" => error } : parse_json(content)
          part[:result_content] = error || content
          part[:error] = error
          part[:state] = error ? :error : :done
          touch(part[:message_id])
        end

        private

        HANDLERS = {
          "RUN_STARTED" => :run_started, "RUN_FINISHED" => :run_finished, "RUN_ERROR" => :run_error,
          "STEP_STARTED" => :step, "STEP_FINISHED" => :step,
          "TEXT_MESSAGE_START" => :text_start, "TEXT_MESSAGE_CONTENT" => :text_content,
          "TEXT_MESSAGE_END" => :text_end,
          "REASONING_MESSAGE_START" => :reasoning_start, "REASONING_MESSAGE_CONTENT" => :reasoning_content,
          "REASONING_MESSAGE_END" => :reasoning_end,
          "REASONING_START" => :noop, "REASONING_END" => :noop, "REASONING_ENCRYPTED_VALUE" => :noop,
          "TOOL_CALL_START" => :tool_start, "TOOL_CALL_ARGS" => :tool_args, "TOOL_CALL_END" => :tool_end,
          "TOOL_CALL_RESULT" => :tool_result,
          "STATE_SNAPSHOT" => :state_snapshot, "STATE_DELTA" => :state_delta,
          "MESSAGES_SNAPSHOT" => :messages_snapshot,
          "ACTIVITY_SNAPSHOT" => :activity_snapshot, "ACTIVITY_DELTA" => :activity_delta,
          "SUBAGENT_STARTED" => :noop, "SUBAGENT_FINISHED" => :noop, "SUBAGENT_ERROR" => :noop,
          "RAW" => :custom, "CUSTOM" => :custom
        }.freeze
        private_constant :HANDLERS

        # An event field by name (verified events are camelCase strings).
        def f(event, name) = event[name]

        # Records a warning and hands it to the callback.
        def report(kind, message)
          warning = ProtocolWarning.new(kind: kind, message: message)
          @warnings << warning
          @on_warning&.call(warning)
        end

        # Ignores an event.
        def noop(_event) = []

        # Records a custom event.
        def custom(event)
          @custom_events << event
          []
        end

        # Records a step event.
        def step(event)
          @steps << [f(event, "type"), f(event, "stepName")]
          []
        end

        # --- run lifecycle ---

        # Starts a run: a new entry in the runs, running.
        def run_started(event)
          @run = { thread_id: f(event, "threadId"), run_id: f(event, "runId"), parent_run_id: f(event, "parentRunId"),
                   status: :running, interrupts: [], error: nil, result: nil }
          @runs << @run
          @version += 1
          []
        end

        # Ends the run by its outcome: interrupted when it carries
        # interrupts, cancelled when it was stopped on purpose, else finished.
        def run_finished(event)
          outcome = f(event, "outcome")
          type = outcome.is_a?(Hash) ? outcome["type"] : nil
          interrupts = type == "interrupt" ? Array(outcome["interrupts"]) : []
          @run[:interrupts] = interrupts.map { |interrupt| stringify(interrupt) }
          @run[:result] = f(event, "result")
          @run[:status] = if interrupts.any?
                            :interrupted
                          elsif type == "cancelled"
                            :cancelled
                          else
                            :finished
                          end
          @version += 1
          close_open_items
        end

        # Marks the run failed with its message and code (a RUN_ERROR that
        # opens the stream is a run of its own).
        def run_error(event)
          @runs << @run unless @runs.any? { |run| run.equal?(@run) }
          @run[:status] = :error
          @run[:error] = { message: f(event, "message").to_s, code: f(event, "code") }
          @version += 1
          close_open_items
        end

        # --- text and reasoning ---

        # Opens a text part on its message, an assistant one unless the event names a role.
        def text_start(event) = start_part(f(event, "messageId"), f(event, "role") || "assistant", :text)
        # Appends a text delta to its message.
        def text_content(event) = append_part(f(event, "messageId"), :text, f(event, "delta"))
        # Closes a message's text part.
        def text_end(event) = end_part(f(event, "messageId"), :text)
        # Opens a reasoning message.
        def reasoning_start(event) = start_part(f(event, "messageId"), "reasoning", :reasoning)
        # Appends a reasoning delta to its message.
        def reasoning_content(event) = append_part(f(event, "messageId"), :reasoning, f(event, "delta"))
        # Closes a reasoning message's part.
        def reasoning_end(event) = end_part(f(event, "messageId"), :reasoning)

        # Opens a text or reasoning part on a message. Text arriving on a
        # reasoning message's id (an older producer sharing one id) makes it
        # an assistant message.
        def start_part(id, role, kind)
          message = ensure_message(id, role)
          message.role = "assistant" if kind == :text && message.role == "reasoning"
          part = { kind: kind, text: +"", state: :streaming }
          message.parts << part
          @open_text[[id, kind]] = part
          [touch(id)]
        end

        # Appends a delta to a message's open part, opening one when a
        # MESSAGES_SNAPSHOT restated the message mid-stream.
        def append_part(id, kind, delta)
          part = @open_text[[id, kind]]
          unless part
            ensure_message(id, kind == :reasoning ? "reasoning" : "assistant")
            part = { kind: kind, text: +"", state: :streaming }
            message(id).parts << part
            @open_text[[id, kind]] = part
          end
          part[:text] = part[:text] + delta.to_s
          [touch(id)]
        end

        # Closes a message's open part: it is done, and its row re-renders.
        def end_part(id, kind)
          part = @open_text.delete([id, kind])
          return [] unless part

          part[:state] = :done
          [touch(id)]
        end

        # A run's end closes whatever text still streams (a RUN_ERROR ends a
        # run mid-message). A tool call whose arguments never closed is
        # abandoned, never settled: acting on arguments before TOOL_CALL_END
        # is what the protocol forbids, so a frontend call never reaches the
        # browser from here. The messages it closed re-render.
        def close_open_items
          closed = @open_text.map do |(id, _kind), part|
            part[:state] = :done
            id
          end
          @open_text.clear
          @tool_args.clear
          closed.uniq.map { |id| touch(id) }
        end

        # --- tool calls ---

        # Opens a tool call on its assistant message, or reopens a closed
        # call with the same id so further arguments append.
        def tool_start(event)
          tool_call_id = f(event, "toolCallId").to_s
          existing = @tool_parts[tool_call_id]
          return reopen_tool(existing) if existing && message(existing[:message_id])

          message_id = tool_message_id(f(event, "parentMessageId"), tool_call_id)
          ensure_message(message_id, "assistant")
          part = { kind: :tool, name: f(event, "toolCallName").to_s, input: nil, output: nil, state: :loading,
                   tool_call_id: tool_call_id, message_id: message_id, arguments: +"" }
          message(message_id).parts << part
          @tool_parts[tool_call_id] = part
          @tool_args[tool_call_id] = part[:arguments]
          [touch(message_id)]
        end

        # A closed call reopened: its arguments stream on from where they stopped.
        def reopen_tool(part)
          part[:arguments] = +part[:arguments].to_s
          part[:input] = nil
          part[:state] = :loading
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == part[:tool_call_id] }
          @tool_args[part[:tool_call_id]] = part[:arguments]
          [touch(part[:message_id])]
        end

        # The assistant message a call belongs to: its parent when that is an
        # assistant message (or not yet seen), else one minted under the
        # call's own id, as the reference client does.
        def tool_message_id(parent_id, tool_call_id)
          return tool_call_id if parent_id.nil?

          parent = message(parent_id.to_s)
          parent && parent.role != "assistant" ? tool_call_id : parent_id.to_s
        end

        # Appends an arguments delta to a tool call.
        def tool_args(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part && @tool_args.key?(tool_call_id)

          @tool_args[tool_call_id] << f(event, "delta").to_s
          [touch(part[:message_id])]
        end

        # Closes a tool call: its arguments settle.
        def tool_end(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          @tool_args.delete(tool_call_id)
          settle_tool(part)
          [touch(part[:message_id])]
        end

        # Settles a call whose arguments are complete: they parse into its
        # input, and a client tool moves to awaiting the browser.
        def settle_tool(part)
          part[:input] = parse_arguments(part[:arguments])
          return unless @client_tools.include?(part[:name]) && part[:state] == :loading

          part[:state] = :awaiting_client
          @pending_client_tools << { tool_call_id: part[:tool_call_id], name: part[:name], input: part[:input],
                                     message_id: part[:message_id] }
        end

        # Records a tool call's result (text or content parts, under the
        # result's own message id) and marks it done.
        def tool_result(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          part[:input] = parse_arguments(part[:arguments]) if @tool_args.delete(tool_call_id) || part[:input].nil?
          part[:result_content] = f(event, "content")
          part[:result_message_id] = f(event, "messageId")&.to_s
          part[:output] = parse_json(part[:result_content])
          part[:state] = :done
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == tool_call_id }
          [touch(part[:message_id])]
        end

        # --- state, messages, activities ---

        # Replaces the state with the snapshot, whatever JSON value it is (null included).
        def state_snapshot(event)
          @state = JsonPatch.deep_copy(f(event, "snapshot"))
          @version += 1
          []
        end

        # Applies a JSON patch to the state. A patch that does not apply
        # leaves the state as it was (application is atomic) and is surfaced
        # as a warning, as AG-UI 1.0 requires.
        def state_delta(event)
          @state = JsonPatch.apply(@state, f(event, "delta"))
          @version += 1
          []
        rescue JsonPatch::Error => e
          report(:patch_failed, "Failed to apply state patch: #{e.message}")
          []
        end

        # Reconciles the messages with a snapshot, as AG-UI 1.0 specifies: a
        # message it carries replaces the copy with the same id in place, one
        # never seen is appended in snapshot order, and one it leaves out is
        # dropped - except activity and reasoning messages, which a snapshot
        # carrying none of that role leaves alone. Answers the ids it
        # changed, dropped ones included.
        def messages_snapshot(event)
          wires = Array(f(event, "messages")).map { |message| stringify(message) }
          carried = wires.map { |wire| wire["role"].to_s }
          @tool_parts = @tool_parts.reject { |_, part| wires.any? { |wire| wire["id"].to_s == part[:message_id] } }
          rebuilt = wires.filter_map { |wire| snapshot_message(wire) }
          fresh = rebuilt.to_h { |message| [message.id, message] }
          kept_roles = %w[activity reasoning] - carried
          survivors = @messages.filter_map do |message|
            fresh.delete(message.id) || (message if kept_roles.include?(message.role))
          end
          dropped = @messages.map(&:id) - survivors.map(&:id)
          @messages = survivors + fresh.values
          @tool_parts.select! { |_, part| message(part[:message_id]) }
          follow_pending_calls
          @activities = @messages.select { |message| message.role == "activity" }.to_h do |message|
            part = message.parts.first
            [message.id, { "type" => part[:activity_type], "content" => part[:content] }]
          end
          @open_text.clear
          follow_open_arguments
          @version += 1
          rebuilt.each { |message| message.version = @version }
          rebuilt.map(&:id) | dropped
        end

        # A call still streaming its arguments that a snapshot restated:
        # further arguments append to the snapshot's copy, the one now shown.
        def follow_open_arguments
          @tool_args.each_key do |tool_call_id|
            part = @tool_parts[tool_call_id]
            @tool_args[tool_call_id] = part[:arguments] = +part[:arguments].to_s if part
          end
        end

        # After a snapshot, the client tools still waiting point at the
        # message that now carries their call; a call the snapshot answered
        # no longer waits.
        def follow_pending_calls
          @pending_client_tools.select! do |pending|
            part = @tool_parts[pending[:tool_call_id]]
            next true unless part
            next false if answered?(part)

            pending[:message_id] = part[:message_id]
            true
          end
        end

        # One snapshot message as a Message - or nil for a tool result, which
        # lands on its call's part instead.
        def snapshot_message(wire)
          id = wire["id"].to_s
          case wire["role"].to_s
          when "user", "system", "developer"
            Message.new(id: id, role: wire["role"].to_s, parts: content_parts(wire["content"]), version: 0)
          when "assistant" then snapshot_assistant(wire)
          when "tool" then snapshot_tool_result(wire)
          when "activity"
            part = { kind: :activity, activity_type: wire["activityType"], content: wire["content"] }
            Message.new(id: id, role: "activity", parts: [part], version: 0)
          when "reasoning"
            Message.new(id: id, role: "reasoning",
                        parts: [{ kind: :reasoning, text: wire["content"].to_s, state: :done }], version: 0)
          end
        end

        # A message's wire content as parts: a string is one text part; a
        # list keeps every content part (text readable as text, the rest as
        # media), each with its wire form for the next run's input.
        def content_parts(content)
          return [{ kind: :text, text: content.to_s, state: :done }] unless content.is_a?(Array)

          content.map do |part|
            if part.is_a?(Hash) && part["type"] == "text"
              { kind: :text, text: part["text"].to_s, state: :done, part: part }
            else
              { kind: :media, part: part }
            end
          end
        end

        # An assistant message rebuilt from its wire form, with its tool calls.
        def snapshot_assistant(wire)
          parts = []
          if wire["content"].is_a?(String) && !wire["content"].empty?
            parts << { kind: :text, text: wire["content"], state: :done }
          end
          Array(wire["toolCalls"]).each do |call|
            function = call["function"] || {}
            arguments = function["arguments"].to_s
            waiting = @pending_client_tools.any? { |pending| pending[:tool_call_id] == call["id"].to_s }
            part = { kind: :tool, name: function["name"].to_s, input: parse_arguments(arguments), output: nil,
                     state: waiting ? :awaiting_client : :loading, tool_call_id: call["id"].to_s,
                     message_id: wire["id"].to_s, arguments: arguments }
            parts << part
            @tool_parts[part[:tool_call_id]] = part
          end
          Message.new(id: wire["id"].to_s, role: "assistant", parts: parts, version: 0)
        end

        # Applies a tool result from a snapshot to its open tool part.
        def snapshot_tool_result(wire)
          part = @tool_parts[wire["toolCallId"].to_s]
          return nil unless part

          part[:output] = wire["error"] ? { "error" => wire["error"] } : parse_json(wire["content"])
          part[:result_content] = wire["content"]
          part[:result_message_id] = wire["id"]&.to_s
          part[:error] = wire["error"]
          part[:state] = wire["error"] ? :error : :done
          nil
        end

        # Replaces an activity's content from a snapshot, unless it asks not to replace an existing one.
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

        # Applies a JSON patch to an activity's content. A delta naming no
        # activity message is skipped with a warning (the spec's tolerated
        # failure), as is one that does not apply. The delta's type replaces
        # the activity's.
        def activity_delta(event)
          id = f(event, "messageId")
          activity = @activities[id]
          target = message(id)
          unless activity && target&.role == "activity"
            report(:activity_missing, "Skipped ACTIVITY_DELTA for '#{id}': no activity message has that id.")
            return []
          end

          activity["content"] = JsonPatch.apply(activity["content"], f(event, "patch"))
          activity["type"] = f(event, "activityType")
          target.parts = [{ kind: :activity, activity_type: activity["type"], content: activity["content"] }]
          [touch(id)]
        rescue JsonPatch::Error => e
          report(:patch_failed, "Failed to apply activity patch for '#{id}': #{e.message}")
          []
        end

        # --- helpers ---

        # The message with an id, added with the role when it is new.
        def ensure_message(id, role)
          id = id.to_s
          message(id) || Message.new(id: id, role: role.to_s, parts: [], version: 0).tap do |created|
            @messages << created
          end
        end

        # Bumps the version and stamps it on a message.
        def touch(id)
          @version += 1
          found = message(id)
          found.version = @version if found
          id
        end

        # A message's text parts joined.
        def text_of(message)
          message.parts.select { |part| part[:kind] == :text }.map { |part| part[:text] }.join
        end

        # A message's reasoning parts joined.
        def reasoning_of(message)
          message.parts.select { |part| part[:kind] == :reasoning }.map { |part| part[:text] }.join
        end

        # A message's content as the wire carries it: the list of parts when
        # it arrived as one, the text otherwise.
        def content_of(message)
          return text_of(message) unless message.parts.any? { |part| part.key?(:part) }

          message.parts.map { |part| part[:part] || { "type" => "text", "text" => part[:text] } }
        end

        # An assistant message in its wire form, with its tool calls and
        # then a tool message for each call that has an answer.
        def assistant_wire(message)
          wire = { "id" => message.id, "role" => "assistant" }
          wire["content"] = text_of(message) if message.parts.any? { |part| part[:kind] == :text }
          calls = message.parts.select { |part| part[:kind] == :tool }
          if calls.any?
            wire["toolCalls"] = calls.map do |part|
              { "id" => part[:tool_call_id], "type" => "function",
                "function" => { "name" => part[:name], "arguments" => arguments_of(part) } }
            end
          end
          [wire, *calls.select { |part| answered?(part) }.map { |part| tool_wire(part) }]
        end

        # A call's arguments as they streamed, or its input as JSON when none streamed.
        def arguments_of(part)
          part[:arguments] || JSON.generate(part[:input] || {})
        end

        # Whether a call has an answer the next run must carry.
        def answered?(part)
          part.key?(:result_content) || !part[:output].nil?
        end

        # A call's answer as a tool message, under the result's own id.
        def tool_wire(part)
          content = part.key?(:result_content) ? part[:result_content] : as_text(part[:output])
          id = part[:result_message_id] || "#{part[:tool_call_id]}-result"
          RunInput.tool_message(part[:tool_call_id], part[:error] || content, error: part[:error], id: id)
        end

        # A value as text: strings as they are, anything else as JSON.
        def as_text(value)
          value.is_a?(String) ? value : JSON.generate(value)
        end

        # Complete tool arguments parsed: an empty string is no arguments.
        def parse_arguments(text)
          text.to_s.empty? ? {} : parse_json(text)
        end

        # Text parsed as JSON when it is; otherwise the value as given.
        def parse_json(text)
          return text unless text.is_a?(String)
          return text if text.empty?

          JSON.parse(text)
        rescue JSON::ParserError
          text
        end

        # A value with every hash key turned into a string, recursively.
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
