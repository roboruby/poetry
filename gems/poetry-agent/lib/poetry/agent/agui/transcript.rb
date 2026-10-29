# frozen_string_literal: true

require "json"
require "securerandom"

module Poetry
  module Agent
    module AGUI
      # Folds an AG-UI event stream into what a chat page renders: the
      # messages in order, each as Chat-shaped parts
      # (`{kind: :text, text:, state:}`, `{kind: :reasoning, text:, state:}`,
      # `{kind: :tool, name:, input:, output:, state:, tool_call_id:, metadata:}`,
      # `{kind: :media, part:}` for a non-text content part), the shared
      # state (snapshots and JSON Patch deltas), activities, every run's
      # status, outcome and interrupts, the subagent invocations, and the
      # tool calls the browser must execute before the next run. A text or
      # reasoning part is `state: :streaming` until its END event (or the
      # run's end) closes it, then `:done` - the difference between
      # "Thinking" and "Thought". A reasoning message is a message of its
      # own (role `reasoning`), as in AG-UI 1.0.
      #
      # A tool result is a message of its own too, as the protocol models
      # it, kept in the conversation but not among the {#messages} a page
      # renders: its call's part reads the answer (`output`, `state`). So
      # a result that arrives before its call, one whose call never comes,
      # and a second result for one call all survive, and
      # {#messages_for_input} sends each result right after the call it
      # answers, as providers require.
      #
      # Metadata merges into what each event builds, key by key, the last
      # write winning: a message, a tool call, a tool result, an activity.
      # A message carries the `subagentRunId` of the invocation that built
      # it. An encrypted reasoning value is held apart from the parts and
      # returned only in {#messages_for_input}, to the producer that issued
      # it.
      #
      # It reduces VERIFIED events: what a {Pipeline} delivers (Client#run and
      # Relay route the wire through one), so every chunk is already expanded,
      # every id present, and every open item closed by the stream itself. A
      # patch it cannot apply, an activity delta with nothing to patch, an
      # encrypted value naming nothing it holds, or text aimed at an activity
      # message is a {ProtocolWarning}.
      #
      # Every change bumps {#version}, and {#apply} answers the ids of the
      # messages it touched, so a relay re-renders exactly those rows with
      # a monotonic version the page's versioned replace honors.
      class Transcript
        # One message. `role` is the protocol's ("user", "assistant",
        # "reasoning", "activity", ...); `parts` is the render-ready list;
        # `metadata`, `subagent_run_id` and `name` are the message's own.
        Message = Struct.new(:id, :role, :parts, :version, :metadata, :subagent_run_id, :name, keyword_init: true)

        # The metadata key a declined call's tool message carries, so the
        # decline survives a round trip through {#messages_for_input}.
        DECLINED = "poetry:tool-result"

        # The shared state after the last snapshot / delta: any JSON value,
        # usually a Hash.
        #
        # @return [Object]
        attr_reader :state

        # The current (latest) run: `{ thread_id:, run_id:, parent_run_id:, status:,
        # interrupts:, error:, result:, usage:, pending_tool_call_ids: }`. Status is
        # :idle, :running, :finished, :interrupted, :cancelled, :error, or
        # :truncated ({#truncate}). `result` is a successful run's; `usage` the
        # producer's token accounting; `pending_tool_call_ids` the calls the run
        # left unanswered (the producer's list, or derived from the calls it
        # started), nil for a cancelled run, which waits for nothing.
        #
        # @return [Hash]
        attr_reader :run

        # Every run the stream carried, in order (each shaped like {#run}),
        # so a first run's failure survives a second run on the same stream.
        #
        # @return [Array<Hash>]
        attr_reader :runs

        # The subagent invocations the stream announced, in order:
        # `{ subagent_run_id:, name:, description:, parent_subagent_run_id:,
        # parent_tool_call_id:, parent_message_id:, status:, outcome:, result:, error: }`.
        # Status is :running, :finished, :suspended (awaiting interrupts), or
        # :error. Work tagged with an id no SUBAGENT_STARTED announced is
        # still attributed on its messages; it has no entry here.
        #
        # @return [Array<Hash>]
        attr_reader :subagents

        # The frontend-defined tool names the browser executes.
        #
        # @return [Array<String>]
        attr_reader :client_tools

        # Tool calls to client tools awaiting execution:
        # `{ tool_call_id:, name:, input:, message_id:, confirm: }`. `confirm` is
        # true for a tool declared to ask the user first.
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

        # An empty transcript, with the client-side tools.
        # @param client_tools [Array<String, Hash>] the tools the browser executes: a
        #   name, or `{ name:, confirm: true }` for one that asks the user first
        # @param on_warning [#call, nil] receives each {ProtocolWarning} as it happens
        def initialize(client_tools: [], on_warning: nil)
          declared = client_tools.map { |tool| tool.is_a?(Hash) ? stringify(tool) : { "name" => tool.to_s } }
          @client_tools = declared.map { |tool| tool["name"].to_s }
          @confirm = declared.select { |tool| tool["confirm"] }.map { |tool| tool["name"].to_s }
          @messages = []
          @state = {}
          @run = { status: :idle, interrupts: [] }
          @runs = []
          @subagents = []
          @pending_client_tools = []
          @custom_events = []
          @warnings = []
          @on_warning = on_warning
          @steps = []
          @version = 0
          @open_text = {}
          @tool_parts = {}
          @tool_args = {}
          @encrypted = {}.compare_by_identity
          @run_calls = []
          @run_answered = []
        end

        # The messages a page renders, in conversation order: every message
        # but the tool results, which their calls' parts carry.
        #
        # @return [Array<Message>]
        def messages
          @messages.reject { |message| message.role == "tool" }
        end

        # Activities by message id: `{ "type" => ..., "content" => ... }`.
        #
        # @return [Hash{String => Hash}]
        def activities
          @messages.select { |message| message.role == "activity" }.to_h do |message|
            part = message.parts.first
            [message.id, { "type" => part[:activity_type], "content" => part[:content] }]
          end
        end

        # Replaces the state, for the one the host sends with a run: the
        # producer's deltas patch what it was sent.
        #
        # @param value [Object] any JSON value
        # @example
        #   transcript.state = input["state"]
        def state=(value)
          @state = JsonPatch.deep_copy(value)
          @version += 1
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

          Array(send(handler, event)).compact.uniq
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
          @messages.find { |message| message.id == id && message.role != "tool" }
        end

        # The subagent invocation with an id, or nil.
        # @param subagent_run_id [String]
        # @return [Hash, nil]
        def subagent(subagent_run_id)
          @subagents.find { |record| record[:subagent_run_id] == subagent_run_id }
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

        # Whether this consumer stopped reading the run before its end ({#truncate}).
        # @return [Boolean]
        def truncated?
          @run[:status] == :truncated
        end

        # Records that this consumer stopped reading a running run - the host
        # broke off the stream, or it died under it. The run becomes
        # :truncated: it did not end, and no RUN_FINISHED is invented for it.
        # What still streamed is closed where it stands.
        #
        # @return [Array<String>] the ids of the messages that changed
        # @example
        #   client.run(input, pipeline: pipeline) { |event| ... }
        #   transcript.truncate if pipeline.truncated?
        def truncate
          return [] unless @run[:status] == :running

          @run[:status] = :truncated
          @version += 1
          close_open_items
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

        # The messages as the next run's `RunAgentInput.messages`: every
        # message in its wire form - content parts kept as parts, tool calls
        # with their arguments exactly as they streamed, each message's and
        # call's metadata, subagentRunId and encrypted value - with each tool
        # result right after the call it answers. Activity messages stay
        # client-side: the protocol requires stripping them.
        #
        # @return [Array<Hash>]
        def messages_for_input
          wires = @messages.map { |message| wire(message) }
          ToolResults.pair(entries).first.map { |index| wires[index] }.reject { |wire| wire["role"] == "activity" }
        end

        # Records a message the host itself sends - its user turn, a tool
        # result, a system prompt, history it restores - so
        # {#messages_for_input} carries the whole conversation and a relay
        # can render it. A tool result answers its call.
        #
        # @param wire [Hash] a protocol message ({RunInput.user_message}, {RunInput.tool_message}, ...)
        # @return [Array<String>] the ids of the messages that changed
        # @example The user's turn, before the run that answers it
        #   user = RunInput.user_message(params[:q])
        #   transcript.add_message(user)
        #   RunInput.build(thread_id: thread, messages: transcript.messages_for_input)
        def add_message(wire)
          added = build(untagged(stringify(wire)))
          return [] unless added

          index = @messages.index { |message| message.id == added.id && tool?(message) == tool?(added) }
          index ? @messages[index] = added : @messages << added
          index_tool_parts
          changed = relink
          ids = tool?(added) ? changed : [added.id] | changed
          ids.map { |id| touch(id) }
        end

        # Records a client tool call's result, so the call reads answered and
        # the next run's input carries the tool message.
        #
        # @param tool_call_id [String]
        # @param content [Object] the result (a string, content parts, or data serialized as JSON)
        # @param error [String, nil]
        # @return [String, nil] the id of the message that changed
        def resolve_client_tool(tool_call_id, content, error: nil)
          answer_client_tool(tool_call_id,
                             RunInput.tool_message(tool_call_id, content, error: error, id: result_id(tool_call_id)))
        end

        # Records that the user declined a client tool call it was asked to
        # approve: the call is answered as declined - never as run - and its
        # part reads :denied.
        #
        # @param tool_call_id [String]
        # @param reason [String] what the agent is told
        # @return [String, nil] the id of the message that changed
        def decline_client_tool(tool_call_id, reason: "The user declined to run this tool.")
          wire = RunInput.tool_message(tool_call_id, reason, error: reason, id: result_id(tool_call_id))
          answer_client_tool(tool_call_id, wire.merge("metadata" => { DECLINED => { "declined" => true } }))
        end

        private

        # The entries a new result goes past to sit after its call.
        BEHIND_A_CALL = %w[tool activity].freeze
        private_constant :BEHIND_A_CALL

        HANDLERS = {
          "RUN_STARTED" => :run_started, "RUN_FINISHED" => :run_finished, "RUN_ERROR" => :run_error,
          "STEP_STARTED" => :step, "STEP_FINISHED" => :step,
          "TEXT_MESSAGE_START" => :text_start, "TEXT_MESSAGE_CONTENT" => :text_content,
          "TEXT_MESSAGE_END" => :text_end,
          "REASONING_MESSAGE_START" => :reasoning_start, "REASONING_MESSAGE_CONTENT" => :reasoning_content,
          "REASONING_MESSAGE_END" => :reasoning_end,
          "REASONING_START" => :noop, "REASONING_END" => :noop, "REASONING_ENCRYPTED_VALUE" => :encrypted_value,
          "TOOL_CALL_START" => :tool_start, "TOOL_CALL_ARGS" => :tool_args, "TOOL_CALL_END" => :tool_end,
          "TOOL_CALL_RESULT" => :tool_result,
          "STATE_SNAPSHOT" => :state_snapshot, "STATE_DELTA" => :state_delta,
          "MESSAGES_SNAPSHOT" => :messages_snapshot,
          "ACTIVITY_SNAPSHOT" => :activity_snapshot, "ACTIVITY_DELTA" => :activity_delta,
          "SUBAGENT_STARTED" => :subagent_started, "SUBAGENT_FINISHED" => :subagent_finished,
          "SUBAGENT_ERROR" => :subagent_error,
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

        # Starts a run: a new entry in the runs, running. Messages the run's
        # echoed input carries that this transcript lacks join it, for a
        # consumer that did not make the request.
        def run_started(event)
          @run = { thread_id: f(event, "threadId"), run_id: f(event, "runId"), parent_run_id: f(event, "parentRunId"),
                   status: :running, interrupts: [], error: nil, result: nil, usage: nil, pending_tool_call_ids: nil }
          @runs << @run
          @run_calls = []
          @run_answered = []
          @version += 1
          echo(f(event, "input"))
        end

        # Adds the echoed input's messages this transcript does not hold.
        def echo(input)
          return [] unless input.is_a?(Hash) && input["messages"].is_a?(Array)

          added = input["messages"].filter_map do |raw|
            wire = untagged(stringify(raw))
            next if @messages.any? { |message| message.id == wire["id"].to_s }

            build(wire)&.tap { |message| @messages << message }
          end
          return [] if added.empty?

          index_tool_parts
          (added.reject { |message| tool?(message) }.map(&:id) | relink).map { |id| touch(id) }
        end

        # Ends the run by its outcome: interrupted when it carries
        # interrupts, cancelled when it was stopped on purpose, else finished.
        def run_finished(event)
          outcome = f(event, "outcome")
          type = outcome.is_a?(Hash) ? outcome["type"] : nil
          interrupts = type == "interrupt" ? Array(outcome["interrupts"]) : []
          @run[:interrupts] = interrupts.map { |interrupt| untagged(stringify(interrupt)) }
          @run[:status] = if interrupts.any?
                            :interrupted
                          elsif type == "cancelled"
                            :cancelled
                          else
                            :finished
                          end
          @run[:result] = @run[:status] == :finished ? f(event, "result") : nil
          @run[:usage] = f(event, "usage")
          @run[:pending_tool_call_ids] = pending_calls(type == "success" ? outcome["pendingToolCallIds"] : nil)
          @version += 1
          close_open_items
        end

        # The calls a run left waiting: the producer's list when it names
        # any, else every call the run started that no result answered. A
        # cancelled run waits for nothing.
        def pending_calls(named)
          return nil if @run[:status] == :cancelled
          return named.dup if named.is_a?(Array) && named.any?

          @run_calls - @run_answered
        end

        # Marks the run failed with its message and code (a RUN_ERROR that
        # opens the stream is a run of its own).
        def run_error(event)
          @runs << @run unless @runs.any? { |run| run.equal?(@run) }
          @run[:status] = :error
          @run[:error] = { message: f(event, "message").to_s, code: f(event, "code") }
          @run[:usage] = f(event, "usage")
          @version += 1
          close_open_items
        end

        # --- text and reasoning ---

        # Opens a text part on its message, an assistant one unless the event names a role.
        def text_start(event) = start_part(event, f(event, "role") || "assistant", :text)
        # Appends a text delta to its message.
        def text_content(event) = append_part(event, :text)
        # Closes a message's text part.
        def text_end(event) = end_part(event, :text)
        # Opens a reasoning message.
        def reasoning_start(event) = start_part(event, "reasoning", :reasoning)
        # Appends a reasoning delta to its message.
        def reasoning_content(event) = append_part(event, :reasoning)
        # Closes a reasoning message's part.
        def reasoning_end(event) = end_part(event, :reasoning)

        # Opens a text or reasoning part on a message; a new message takes the
        # event's name and attribution. Text arriving on a reasoning message's
        # id (an older producer sharing one id) makes it an assistant message.
        def start_part(event, role, kind)
          id = f(event, "messageId").to_s
          existing = message(id)
          return collision(event, id, "activity") if existing&.role == "activity"
          return collision(event, id, "tool") if existing.nil? && @messages.any? { |held| held.id == id }

          target = existing || append(Message.new(id: id, role: role.to_s, parts: [], version: 0,
                                                  name: f(event, "name"), subagent_run_id: f(event, "subagentRunId")))
          target.role = "assistant" if kind == :text && target.role == "reasoning"
          merge_metadata(target, event)
          part = { kind: kind, text: +"", state: :streaming }
          target.parts << part
          @open_text[[id, kind]] = part
          [touch(id)]
        end

        # Appends a delta to a message's open part, opening one when a
        # MESSAGES_SNAPSHOT restated the message mid-stream.
        def append_part(event, kind)
          id = f(event, "messageId").to_s
          return collision(event, id, "activity") if message(id)&.role == "activity"
          return collision(event, id, "tool") if message(id).nil? && @messages.any? { |held| held.id == id }

          part = @open_text[[id, kind]]
          unless part
            part = { kind: kind, text: +"", state: :streaming }
            ensure_message(id, kind == :reasoning ? "reasoning" : "assistant").parts << part
            @open_text[[id, kind]] = part
          end
          part[:text] = part[:text] + f(event, "delta").to_s
          merge_metadata(message(id), event)
          [touch(id)]
        end

        # Closes a message's open part: it is done, and its row re-renders.
        def end_part(event, kind)
          id = f(event, "messageId").to_s
          target = message(id)
          return collision(event, id, "activity") if target&.role == "activity"
          return collision(event, id, "tool") if target.nil? && @messages.any? { |held| held.id == id }

          part = @open_text.delete([id, kind])
          part[:state] = :done if part
          changed = merge_metadata(target, event)
          part || changed ? [touch(id)] : []
        end

        # Text or reasoning aimed at an activity message or a tool result:
        # ignored, since message ids are unique and neither may be overwritten.
        def collision(event, id, role)
          held = role == "activity" ? "an activity" : "a tool"
          report(:id_collision, "#{f(event, "type")}: Message '#{id}' is #{held} message - message ids must be " \
                                "unique across #{role} and text messages.")
          []
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
          @run_calls << tool_call_id unless @run_calls.include?(tool_call_id)
          existing = @tool_parts[tool_call_id]
          return reopen_tool(existing, event) if existing && message(existing[:message_id])

          message_id = tool_message_id(f(event, "parentMessageId"), tool_call_id)
          created = message(message_id).nil?
          owner = ensure_message(message_id, "assistant")
          owner.subagent_run_id ||= f(event, "subagentRunId") if created
          part = { kind: :tool, name: f(event, "toolCallName").to_s, input: nil, output: nil, state: :loading,
                   tool_call_id: tool_call_id, message_id: message_id, arguments: +"" }
          merge_metadata(part, event)
          owner.parts << part
          @tool_parts[tool_call_id] = part
          @tool_args[tool_call_id] = part[:arguments]
          ([message_id] | relink).map { |id| touch(id) }
        end

        # A closed call reopened: its arguments stream on from where they
        # stopped, under the name the event gives.
        def reopen_tool(part, event)
          name = f(event, "toolCallName").to_s
          unless name == part[:name]
            report(:id_collision, "TOOL_CALL_START: tool call '#{part[:tool_call_id]}' already exists with name " \
                                  "'#{part[:name]}' - updating it to '#{name}'.")
          end
          part[:name] = name
          part[:arguments] = +part[:arguments].to_s
          part[:input] = nil
          part[:state] = :loading
          merge_metadata(part, event)
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == part[:tool_call_id] }
          @tool_args[part[:tool_call_id]] = part[:arguments]
          [touch(part[:message_id])]
        end

        # The assistant message a call belongs to: its parent when that is an
        # assistant message (or not yet seen), else one minted under the
        # call's own id, as the reference client does.
        def tool_message_id(parent_id, tool_call_id)
          return tool_call_id if parent_id.nil?

          parent = @messages.find { |message| message.id == parent_id.to_s }
          return parent_id.to_s unless parent && parent.role != "assistant"

          report(:id_collision, "TOOL_CALL_START: parentMessageId '#{parent_id}' matches a '#{parent.role}' message, " \
                                "not assistant - falling back to toolCallId '#{tool_call_id}'.")
          tool_call_id
        end

        # Appends an arguments delta to a tool call.
        def tool_args(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part && @tool_args.key?(tool_call_id)

          @tool_args[tool_call_id] << f(event, "delta").to_s
          merge_metadata(part, event)
          [touch(part[:message_id])]
        end

        # Closes a tool call: its arguments settle.
        def tool_end(event)
          tool_call_id = f(event, "toolCallId").to_s
          part = @tool_parts[tool_call_id]
          return [] unless part

          @tool_args.delete(tool_call_id)
          merge_metadata(part, event)
          settle_tool(part)
          [touch(part[:message_id])]
        end

        # Settles a call whose arguments are complete: they parse into its
        # input, and a client tool moves to awaiting the browser (its part
        # marked `confirm: true` when the tool asks the user first).
        def settle_tool(part)
          part[:input] = parse_arguments(part[:arguments])
          return unless @client_tools.include?(part[:name]) && part[:state] == :loading

          part[:state] = :awaiting_client
          part[:confirm] = true if @confirm.include?(part[:name])
          @pending_client_tools << { tool_call_id: part[:tool_call_id], name: part[:name], input: part[:input],
                                     message_id: part[:message_id], confirm: @confirm.include?(part[:name]) }
        end

        # Records a tool result as a message of its own - in place when it
        # restates one, else right after the call it answers - and the call
        # reads it.
        def tool_result(event)
          tool_call_id = f(event, "toolCallId").to_s
          id = f(event, "messageId").to_s
          @run_answered << tool_call_id
          part = @tool_parts[tool_call_id]
          if part && (@tool_args.delete(tool_call_id) || part[:input].nil?)
            part[:input] =
              parse_arguments(part[:arguments])
          end
          index = @messages.index { |entry| tool?(entry) && entry.id == id && call_id(entry) == tool_call_id }
          result = index ? @messages[index] : Message.new(id: id, role: "tool", version: 0)
          result.parts = [{ kind: :result, tool_call_id: tool_call_id, content: f(event, "content"), error: nil }]
          result.subagent_run_id = f(event, "subagentRunId")
          merge_metadata(result, event)
          place_result(result, tool_call_id) unless index
          @version += 1
          relink.map { |changed| touch(changed) }
        end

        # A new result goes after the newest call with its id that no later
        # result answers (or the newest call with its id), past the results
        # and activities already behind it; with no call, at the end.
        def place_result(result, tool_call_id)
          owner = newest = nil
          answered = false
          (@messages.size - 1).downto(0) do |index|
            entry = @messages[index]
            if tool?(entry) && call_id(entry) == tool_call_id
              answered = true
            elsif issued(entry).include?(tool_call_id)
              newest ||= index
              unless answered
                owner = index
                break
              end
              answered = false
            end
          end
          owner ||= newest
          return @messages << result unless owner

          at = owner + 1
          at += 1 while at < @messages.size && BEHIND_A_CALL.include?(@messages[at].role)
          @messages.insert(at, result)
        end

        # A client tool's answer, from the browser.
        def answer_client_tool(tool_call_id, wire)
          part = @tool_parts[tool_call_id]
          @pending_client_tools.reject! { |pending| pending[:tool_call_id] == tool_call_id }
          return nil unless part

          add_message(wire)
          part[:message_id]
        end

        # An id for a browser's result: the call's own "-result", unless a
        # message already has it (a provider reusing call ids every turn).
        def result_id(tool_call_id)
          candidate = "#{tool_call_id}-result"
          @messages.any? { |message| message.id == candidate } ? "#{candidate}-#{SecureRandom.hex(4)}" : candidate
        end

        # Pairs every result with the call it answers ({ToolResults}) and has
        # each call read its answer; a call whose result went away reads
        # unanswered again. Answers the ids of the messages whose calls changed.
        def relink
          before = all_tool_parts.map { |part| [part, part[:result_message_id], part[:state]] }
          answers = {}.compare_by_identity
          ToolResults.pair(entries).last.each do |index, (issuer, nth)|
            result = @messages[index]
            calls = tool_parts_of(@messages[issuer]).select { |part| part[:tool_call_id] == call_id(result) }
            answers[calls[nth]] = result if calls[nth]
          end
          all_tool_parts.each { |part| answers.key?(part) ? answer(part, answers[part]) : unanswer(part) }
          follow_pending_calls
          before.filter_map do |part, result_id, state|
            part[:message_id] if part[:result_message_id] != result_id || part[:state] != state
          end.uniq
        end

        # A call reads its result: the content (parsed when it is JSON), the
        # error, and done, failed or declined.
        def answer(part, result)
          data = result.parts.first
          part[:result_content] = data[:content]
          part[:result_message_id] = result.id
          part[:error] = data[:error]
          part[:output] = data[:error] ? { "error" => data[:error] } : parse_json(data[:content])
          part[:state] = if result.metadata.is_a?(Hash) && result.metadata.dig(DECLINED, "declined") == true
                           :denied
                         else
                           data[:error] ? :error : :done
                         end
        end

        # A call whose result is gone waits again.
        def unanswer(part)
          return unless part.key?(:result_content)

          %i[result_content result_message_id error].each { |key| part.delete(key) }
          part[:output] = nil
          waiting = @pending_client_tools.any? { |pending| pending[:tool_call_id] == part[:tool_call_id] }
          part[:state] = waiting ? :awaiting_client : :loading
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
        # carrying none of that role leaves alone. A result the merge left
        # away from its call moves back beside it. Answers the ids it
        # changed, dropped ones included.
        def messages_snapshot(event)
          wires = Array(f(event, "messages")).map { |wire| untagged(stringify(wire)) }
          fresh = wires.to_h { |wire| [wire["id"].to_s, wire] }
          kept_roles = %w[activity reasoning] - wires.map { |wire| wire["role"].to_s }
          before = messages.map(&:id)
          taken = {}
          survivors = @messages.filter_map do |message|
            if fresh.key?(message.id) && !taken[message.id]
              taken[message.id] = true
              build(fresh[message.id])
            elsif kept_roles.include?(message.role)
              message
            end
          end
          appended = fresh.keys.reject { |id| taken[id] }.filter_map { |id| build(fresh[id]) }
          built = survivors.reject { |message| @messages.any? { |held| held.equal?(message) } } + appended
          @messages = survivors + appended
          @messages = ToolResults.pair(entries).first.map { |index| @messages[index] }
          forget_encrypted
          index_tool_parts
          @open_text.clear
          follow_open_arguments
          relink
          @version += 1
          rebuilt = built.reject { |message| tool?(message) }
          rebuilt.each { |message| message.version = @version }
          (fresh.keys & rebuilt.map(&:id)) | (before - messages.map(&:id))
        end

        # A call still streaming its arguments that a snapshot restated:
        # further arguments append to the snapshot's copy, the one now shown.
        def follow_open_arguments
          @tool_args.each_key do |tool_call_id|
            part = @tool_parts[tool_call_id]
            @tool_args[tool_call_id] = part[:arguments] = +part[:arguments].to_s if part
          end
        end

        # The client tools still waiting point at the message that now carries
        # their call; a call that has its answer no longer waits.
        def follow_pending_calls
          @pending_client_tools.select! do |pending|
            part = @tool_parts[pending[:tool_call_id]]
            next true unless part
            next false if part.key?(:result_content)

            pending[:message_id] = part[:message_id]
            true
          end
        end

        # One wire message as a Message, nil for a role no message has.
        def build(wire)
          id = wire["id"].to_s
          role = wire["role"].to_s
          built = case role
                  when "user", "system", "developer"
                    Message.new(id: id, role: role, parts: content_parts(wire["content"]))
                  when "assistant" then build_assistant(wire)
                  when "tool"
                    Message.new(id: id, role: "tool", parts: [{ kind: :result, tool_call_id: wire["toolCallId"].to_s,
                                                                content: wire["content"], error: wire["error"] }])
                  when "activity"
                    Message.new(id: id, role: "activity",
                                parts: [{ kind: :activity, activity_type: wire["activityType"],
                                          content: JsonPatch.deep_copy(wire["content"]) }])
                  when "reasoning"
                    Message.new(id: id, role: "reasoning",
                                parts: [{ kind: :reasoning, text: wire["content"].to_s, state: :done }])
                  end
          return nil unless built

          built.version = 0
          built.name = wire["name"]
          built.metadata = JsonPatch.deep_copy(wire["metadata"]) if wire["metadata"].is_a?(Hash)
          built.subagent_run_id = wire["subagentRunId"]
          @encrypted[built] = wire["encryptedValue"] if wire.key?("encryptedValue") && role != "activity"
          built
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
        def build_assistant(wire)
          parts = []
          parts << { kind: :text, text: wire["content"], state: :done } if wire["content"].is_a?(String)
          Array(wire["toolCalls"]).each do |call|
            next unless call.is_a?(Hash)

            function = call["function"].is_a?(Hash) ? call["function"] : {}
            arguments = function["arguments"].to_s
            waiting = @pending_client_tools.any? { |pending| pending[:tool_call_id] == call["id"].to_s }
            part = { kind: :tool, name: function["name"].to_s, input: parse_arguments(arguments), output: nil,
                     state: waiting ? :awaiting_client : :loading, tool_call_id: call["id"].to_s,
                     message_id: wire["id"].to_s, arguments: arguments }
            part[:metadata] = JsonPatch.deep_copy(call["metadata"]) if call["metadata"].is_a?(Hash)
            @encrypted[part] = call["encryptedValue"] if call.key?("encryptedValue")
            parts << part
          end
          Message.new(id: wire["id"].to_s, role: "assistant", parts: parts)
        end

        # Replaces an activity's content from a snapshot (unless it asks not
        # to replace one); accumulated metadata survives the replacement.
        def activity_snapshot(event)
          id = f(event, "messageId").to_s
          index = @messages.index { |message| message.id == id }
          existing = index && @messages[index]
          replace = f(event, "replace") != false
          activity = { kind: :activity, activity_type: f(event, "activityType"),
                       content: JsonPatch.deep_copy(f(event, "content")) }
          if existing&.role == "activity"
            if replace
              existing.parts = [activity]
              existing.subagent_run_id = f(event, "subagentRunId")
            end
            merge_metadata(existing, event)
          elsif existing.nil? || replace
            created = Message.new(id: id, role: "activity", parts: [activity], version: 0,
                                  subagent_run_id: f(event, "subagentRunId"))
            merge_metadata(created, event)
            existing ? @messages[index] = created : @messages << created
          else
            return []
          end
          [touch(id)]
        end

        # Applies a JSON patch to an activity's content. A delta naming no
        # activity message is skipped with a warning (the spec's tolerated
        # failure), as is one that does not apply. The delta's type replaces
        # the activity's.
        def activity_delta(event)
          id = f(event, "messageId")
          target = message(id)
          unless target&.role == "activity"
            report(:activity_missing, "Skipped ACTIVITY_DELTA for '#{id}': no activity message has that id.")
            return []
          end

          merge_metadata(target, event)
          part = target.parts.first
          target.parts = [{ kind: :activity, activity_type: f(event, "activityType"),
                            content: JsonPatch.apply(part[:content], f(event, "patch")) }]
          [touch(id)]
        rescue JsonPatch::Error => e
          report(:patch_failed, "Failed to apply activity patch for '#{id}': #{e.message}")
          []
        end

        # --- reasoning artefacts and subagents ---

        # Stores an encrypted reasoning value with the message or tool call it
        # names, opaque, for the next run's input. One naming nothing this
        # transcript holds (or an activity message) is dropped with a warning.
        def encrypted_value(event)
          entity = f(event, "entityId").to_s
          tool_call = f(event, "subtype") == "tool-call"
          target = if tool_call
                     all_tool_parts.find { |part| part[:tool_call_id] == entity }
                   else
                     found = @messages.find { |message| message.id == entity }
                     found unless found&.role == "activity"
                   end
          unless target
            report(:unknown_entity, "Dropped REASONING_ENCRYPTED_VALUE for '#{entity}': no " \
                                    "#{tool_call ? "tool call" : "message"} has that id.")
            return []
          end

          @encrypted[target] = f(event, "encryptedValue")
          @version += 1
          []
        end

        # Records an invocation's start (a resumed one starts again).
        def subagent_started(event)
          id = f(event, "subagentRunId")
          record = subagent(id) || { subagent_run_id: id }.tap { |created| @subagents << created }
          record.merge!(name: f(event, "name"), description: f(event, "description"),
                        parent_subagent_run_id: f(event, "parentSubagentRunId"),
                        parent_tool_call_id: f(event, "parentToolCallId"),
                        parent_message_id: f(event, "parentMessageId"),
                        status: :running, outcome: nil, result: nil, error: nil)
          @version += 1
          owner(record)
        end

        # Records an invocation's end: finished, or suspended awaiting interrupts.
        def subagent_finished(event)
          record = subagent(f(event, "subagentRunId"))
          return [] unless record

          outcome = f(event, "outcome")
          record[:status] = outcome.is_a?(Hash) && outcome["type"] == "suspended" ? :suspended : :finished
          record[:outcome] = stringify(outcome)
          record[:result] = f(event, "result")
          @version += 1
          owner(record)
        end

        # Records an invocation's failure; the run goes on.
        def subagent_error(event)
          record = subagent(f(event, "subagentRunId"))
          return [] unless record

          record[:status] = :error
          record[:error] = { message: f(event, "message").to_s, code: f(event, "code") }
          @version += 1
          owner(record)
        end

        # The messages an invocation's change re-renders: the one that
        # delegated to it, and the ones it built.
        def owner(record)
          parent = @tool_parts[record[:parent_tool_call_id].to_s]&.dig(:message_id) || record[:parent_message_id]
          built = messages.select { |message| message.subagent_run_id == record[:subagent_run_id] }.map(&:id)
          ([parent].compact.select { |id| message(id) } | built).map { |id| touch(id) }
        end

        # --- helpers ---

        # The message with an id, added with the role when it is new.
        def ensure_message(id, role)
          message(id.to_s) || append(Message.new(id: id.to_s, role: role.to_s, parts: [], version: 0))
        end

        # Adds a message at the end.
        def append(message)
          @messages << message
          message
        end

        # Folds an event's metadata into what it builds (a message or a tool
        # call part), key by key, the last write winning, never recursing;
        # the merged metadata, or nil when the event carried none.
        def merge_metadata(target, event)
          incoming = event["metadata"]
          return nil unless target && incoming.is_a?(Hash)

          target[:metadata] = (target[:metadata] || {}).merge(JsonPatch.deep_copy(incoming))
        end

        # Bumps the version and stamps it on a message.
        def touch(id)
          @version += 1
          found = message(id)
          found.version = @version if found
          id
        end

        # Whether a message is a tool result.
        def tool?(message) = message.role == "tool"

        # The call a tool result answers.
        def call_id(result) = result.parts.first[:tool_call_id]

        # A message's tool call parts.
        def tool_parts_of(message)
          message.role == "assistant" ? message.parts.select { |part| part[:kind] == :tool } : []
        end

        # Every tool call part, in conversation order.
        def all_tool_parts = @messages.flat_map { |message| tool_parts_of(message) }

        # The call ids a message issues.
        def issued(message) = tool_parts_of(message).map { |part| part[:tool_call_id] }

        # The conversation as {ToolResults} reads it.
        def entries
          @messages.map do |message|
            [message.role, (call_id(message) if tool?(message)), issued(message)]
          end
        end

        # Each call id to its newest part, for the events that name a call.
        def index_tool_parts
          @tool_parts = all_tool_parts.to_h { |part| [part[:tool_call_id], part] }
        end

        # Lets go of encrypted values whose message or call a snapshot replaced.
        def forget_encrypted
          live = {}.compare_by_identity
          @messages.each do |message|
            live[message] = true
            message.parts.each { |part| live[part] = true }
          end
          @encrypted.select! { |holder, _| live.key?(holder) }
        end

        # The stored conversation in wire form, tool results and activity
        # messages where they sit (what the apply vectors compare).
        def stored_wire = @messages.map { |message| wire(message) }

        # One message in its wire form.
        def wire(message)
          wire = { "id" => message.id, "role" => message.role }
          case message.role
          when "assistant"
            wire["content"] = text_of(message) if message.parts.any? { |part| part[:kind] == :text }
            calls = tool_parts_of(message)
            wire["toolCalls"] = calls.map { |part| call_wire(part) } if calls.any?
          when "tool"
            data = message.parts.first
            wire["toolCallId"] = data[:tool_call_id]
            wire["content"] = data[:content]
            wire["error"] = data[:error] unless data[:error].nil?
          when "activity"
            part = message.parts.first
            wire["activityType"] = part[:activity_type]
            wire["content"] = part[:content]
          when "reasoning" then wire["content"] = text_of(message, :reasoning)
          else wire["content"] = content_of(message)
          end
          wire["name"] = message.name if message.name
          wire["metadata"] = message.metadata if message.metadata
          wire["subagentRunId"] = message.subagent_run_id if message.subagent_run_id
          wire["encryptedValue"] = @encrypted[message] if @encrypted.key?(message)
          wire
        end

        # A tool call in its wire form, its arguments exactly as they streamed.
        def call_wire(part)
          call = { "id" => part[:tool_call_id], "type" => "function",
                   "function" => { "name" => part[:name], "arguments" => arguments_of(part) } }
          call["metadata"] = part[:metadata] if part[:metadata]
          call["encryptedValue"] = @encrypted[part] if @encrypted.key?(part)
          call
        end

        # A message's parts of one kind joined.
        def text_of(message, kind = :text)
          message.parts.select { |part| part[:kind] == kind }.map { |part| part[:text] }.join
        end

        # A message's content as the wire carries it: the list of parts when
        # it arrived as one, the text otherwise.
        def content_of(message)
          return text_of(message) unless message.parts.any? { |part| part.key?(:part) }

          message.parts.map { |part| part[:part] || { "type" => "text", "text" => part[:text] } }
        end

        # A call's arguments as they streamed, or its input as JSON when none streamed.
        def arguments_of(part)
          part[:arguments] || JSON.generate(part[:input] || {})
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

        # A wire hash without a null `subagentRunId`, which means none.
        def untagged(wire)
          return wire unless wire.is_a?(Hash) && wire.key?("subagentRunId") && wire["subagentRunId"].nil?

          wire.except("subagentRunId")
        end
      end
    end
  end
end
