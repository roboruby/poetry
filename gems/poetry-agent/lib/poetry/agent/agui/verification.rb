# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # Stream verification, a port of the TypeScript client's verify/verify.ts:
      # the run lifecycle, open/close discipline for every streamed entity,
      # ownership agreement on `subagentRunId`, and nothing open at RUN_FINISHED.
      # It runs after enforcement and chunk expansion, so it sees schema-valid,
      # expanded events only.
      #
      #   verify = Verification.new
      #   verify.call(event) # => event, or raises ProtocolError (stage :verification)
      #
      # Every check runs before any state changes, so a rejected event leaves the
      # tracking exactly as it was (lenient mode drops it and carries on).
      #
      # Not ported, because enforcement already rejects the same events: the
      # `subagentRunId: null` tolerance, the lifecycle-optional null checks, the
      # SUBAGENT_* "without a 'subagentRunId' / 'name' / 'message'" checks, the
      # outcome-type and interruptIds checks, and the nested-null checks on
      # snapshot messages and interrupts. verify.ts keeps them for in-process
      # producers that skip enforcement; this pipeline has no such path.
      class Verification
        # How rejections name the parent agent as an owner.
        PARENT = "(the parent agent)"

        # A verifier awaiting a stream's first event.
        def initialize
          @first_seen = false
          @run_started = false
          @run_finished = false
          @run_error = false
          reset_tracking
        end

        # A run is open: started (or errored first) and not yet closed.
        def run_open? = @run_started && !@run_finished && !@run_error

        # One event checked against the stream so far, and recorded once accepted.
        # @param event [Hash] an enforced, expanded event
        # @return [Hash] the event itself
        # @raise [ProtocolError] for an event the stream does not allow, before any tracking changes
        def call(event)
          type = event["type"]
          check_lifecycle(type)
          commit = send(HANDLERS.fetch(type, :pass), event)
          # The lifecycle bookkeeping, now that the event is accepted.
          if type == "RUN_STARTED" && (@run_finished || @run_error)
            reset_tracking
            @run_finished = false
            @run_error = false
          end
          @first_seen = true
          commit&.call
          event
        end

        # Whether any event has been accepted.
        def seen? = @first_seen

        # The tool calls whose arguments are still streaming.
        # @return [Array<String>]
        def open_tool_calls = @open_tool_calls.to_a

        # Lenient mode only, for the two rejections of a well-formed run boundary
        # that are about what came BEFORE it. What the run left open is treated
        # as abandoned, the way RUN_ERROR ends whatever was still open, so the
        # boundary can be admitted: :open_at_finish closes nothing and forgets
        # the open entities; :nested_run treats the previous run as closed.
        #
        # @param kind [Symbol] the rejection being admitted (:open_at_finish or :nested_run)
        # @return [void]
        # @raise [ArgumentError] for any other kind
        def abandon!(kind)
          case kind
          when :open_at_finish
            [@open_messages, @open_tool_calls, @open_spans, @open_reasoning, @active_subagents].each(&:clear)
            @steps.clear
          when :nested_run then @run_finished = true
          else raise ArgumentError, "nothing to abandon for #{kind.inspect}"
          end
        end

        private

        HANDLERS = {
          "TEXT_MESSAGE_START" => :text_start, "TEXT_MESSAGE_CONTENT" => :text_continue,
          "TEXT_MESSAGE_END" => :text_continue,
          "TOOL_CALL_START" => :tool_start, "TOOL_CALL_ARGS" => :tool_continue, "TOOL_CALL_END" => :tool_continue,
          "TOOL_CALL_RESULT" => :tool_result,
          "REASONING_START" => :reasoning_start, "REASONING_MESSAGE_START" => :reasoning_start,
          "REASONING_MESSAGE_CONTENT" => :reasoning_continue, "REASONING_MESSAGE_END" => :reasoning_continue,
          "REASONING_END" => :reasoning_continue, "REASONING_ENCRYPTED_VALUE" => :encrypted_value,
          "STEP_STARTED" => :step_started, "STEP_FINISHED" => :step_finished,
          "ACTIVITY_SNAPSHOT" => :activity_snapshot, "ACTIVITY_DELTA" => :activity_delta,
          "SUBAGENT_STARTED" => :subagent_started, "SUBAGENT_FINISHED" => :subagent_terminal,
          "SUBAGENT_ERROR" => :subagent_terminal,
          "MESSAGES_SNAPSHOT" => :messages_snapshot,
          "RUN_STARTED" => :run_started, "RUN_FINISHED" => :run_finished, "RUN_ERROR" => :run_error
        }.freeze
        private_constant :HANDLERS

        # Empty tracking for a new run: nothing open, no owners, no steps.
        def reset_tracking
          @open_messages = Set.new
          @open_tool_calls = Set.new
          # Reasoning has two bracketed entities: a span (REASONING_START/END) and
          # a message (REASONING_MESSAGE_START/END). One id may name both.
          @open_spans = Set.new
          @open_reasoning = Set.new
          # Owners per entity KIND, retained after close for the whole run: a
          # continuation (an encrypted value after TOOL_CALL_END) can arrive late.
          # Value nil means the parent agent; no key means no owner on record.
          @owners = { message: {}, tool_call: {}, activity: {}, reasoning: {} }
          @steps = Hash.new { |hash, owner| hash[owner] = Set.new } # owner => step names (nil and "" distinct)
          @active_subagents = Set.new
          @closed_subagents = Set.new
        end

        # Rejects an event the run's lifecycle does not allow here.
        def check_lifecycle(type)
          if @run_error && type != "RUN_STARTED"
            fail!("Cannot send event type '#{type}': The run has already errored with 'RUN_ERROR'. " \
                  "No further events can be sent.")
          end
          if @run_finished && type != "RUN_ERROR" && type != "RUN_STARTED"
            fail!("Cannot send event type '#{type}': The run has already finished with 'RUN_FINISHED'. " \
                  "Start a new run with 'RUN_STARTED'.")
          end
          if !@first_seen
            fail!("First event must be 'RUN_STARTED'") unless %w[RUN_STARTED RUN_ERROR].include?(type)
          elsif type == "RUN_STARTED" && run_open?
            fail!("Cannot send 'RUN_STARTED' while a run is still active. The previous run must be finished with " \
                  "'RUN_FINISHED' before starting a new run.", kind: :nested_run)
          end
        end

        # An absent tag never disagrees. A recorded owner of nil is the parent
        # agent, which is as much an owner as a subagent is.
        def check_owner!(type, tag, bucket, kind, id)
          return if tag.nil? || !@owners[bucket].key?(id)

          owner = @owners[bucket][id]
          return if owner == tag

          fail!("Cannot send '#{type}': subagentRunId '#{tag}' does not match the #{kind} '#{id}' opener's subagent " \
                "'#{owner.nil? ? PARENT : owner}'.")
        end

        # No checks and nothing to record.
        def pass(_event) = nil

        # --- text messages ---

        # The commit that opens a text message, once its id is free and its tag agrees.
        def text_start(event)
          id = event["messageId"]
          if @open_messages.include?(id)
            fail!("Cannot send 'TEXT_MESSAGE_START' event: A text message with ID '#{id}' is already in progress. " \
                  "Complete it with 'TEXT_MESSAGE_END' first.")
          end
          check_owner!("TEXT_MESSAGE_START", event["subagentRunId"], :message, "message", id)
          lambda do
            @open_messages << id
            @owners[:message][id] = event["subagentRunId"] unless @owners[:message].key?(id) # first writer wins
          end
        end

        # Checks content or an end against an open text message; the end's commit closes it.
        def text_continue(event)
          type = event["type"]
          id = event["messageId"]
          unless @open_messages.include?(id)
            hint = if type == "TEXT_MESSAGE_END" then "A 'TEXT_MESSAGE_START' event must be sent first."
                   else "Start a text message with 'TEXT_MESSAGE_START' first."
                   end
            fail!("Cannot send '#{type}' event: No active text message found with ID '#{id}'. #{hint}")
          end
          check_owner!(type, event["subagentRunId"], :message, "message", id)
          -> { @open_messages.delete(id) } if type == "TEXT_MESSAGE_END"
        end

        # --- tool calls ---

        # The commit that opens a tool call and records its owner, inherited from its parent message
        # when untagged.
        def tool_start(event)
          id = event["toolCallId"]
          tag = event["subagentRunId"]
          parent_id = event["parentMessageId"]
          if @open_tool_calls.include?(id)
            fail!("Cannot send 'TOOL_CALL_START' event: A tool call with ID '#{id}' is already in progress. " \
                  "Complete it with 'TOOL_CALL_END' first.")
          end
          # A call lives inside the message parentMessageId names, and ToolCall
          # has no attribution of its own: an untagged call inherits that owner,
          # a tag disagreeing with it cannot be represented.
          inherited = :none
          if !parent_id.nil? && @owners[:message].key?(parent_id)
            parent_owner = @owners[:message][parent_id]
            if !tag.nil? && tag != parent_owner
              fail!("Cannot send 'TOOL_CALL_START': subagentRunId '#{tag}' does not match its parent message " \
                    "'#{parent_id}' owner '#{parent_owner.nil? ? PARENT : parent_owner}'. A tool call belongs to the " \
                    "message that carries it.")
            end
            inherited = parent_owner
          end
          if @owners[:tool_call].key?(id)
            existing = @owners[:tool_call][id]
            check_owner!("TOOL_CALL_START", tag, :tool_call, "tool call", id)
            if tag.nil? && inherited != :none && inherited != existing
              fail!("Cannot send 'TOOL_CALL_START': tool call '#{id}' is owned by " \
                    "'#{existing.nil? ? PARENT : existing}' " \
                    "but its parent message '#{parent_id}' is owned by '#{inherited.nil? ? PARENT : inherited}'. " \
                    "A tool call belongs to the message that carries it.")
            end
          end
          lambda do
            @open_tool_calls << id
            unless @owners[:tool_call].key?(id)
              @owners[:tool_call][id] = tag.nil? && inherited != :none ? inherited : tag
            end
          end
        end

        # Checks args or an end against an open tool call; the end's commit closes it.
        def tool_continue(event)
          type = event["type"]
          id = event["toolCallId"]
          unless @open_tool_calls.include?(id)
            hint = if type == "TOOL_CALL_END" then "A 'TOOL_CALL_START' event must be sent first."
                   else "Start a tool call with 'TOOL_CALL_START' first."
                   end
            fail!("Cannot send '#{type}' event: No active tool call found with ID '#{id}'. #{hint}")
          end
          check_owner!(type, event["subagentRunId"], :tool_call, "tool call", id)
          -> { @open_tool_calls.delete(id) } if type == "TOOL_CALL_END"
        end

        # A creation event: it mints the tool message, so its id goes on record
        # (newest mint wins: the executor may differ from the caller).
        def tool_result(event)
          id = event["messageId"]
          -> { @owners[:message][id] = event["subagentRunId"] } if id.is_a?(String)
        end

        # --- reasoning ---

        # The commit that opens a reasoning span or message, once its id is free and its tag agrees.
        def reasoning_start(event)
          type = event["type"]
          id = event["messageId"]
          span = type == "REASONING_START"
          open = span ? @open_spans : @open_reasoning
          if open.include?(id)
            if span
              fail!("Cannot send 'REASONING_START' event: A reasoning span with ID '#{id}' is already in progress. " \
                    "Complete it with 'REASONING_END' first.")
            end
            fail!("Cannot send 'REASONING_MESSAGE_START' event: A reasoning message with ID '#{id}' is already in " \
                  "progress. Complete it with 'REASONING_MESSAGE_END' first.")
          end
          check_owner!(type, event["subagentRunId"], :reasoning, "reasoning message", id)
          lambda do
            open << id
            @owners[:reasoning][id] = event["subagentRunId"] unless @owners[:reasoning].key?(id)
          end
        end

        # Checks content or an end against an open reasoning span or message; an end's commit closes it.
        def reasoning_continue(event)
          type = event["type"]
          id = event["messageId"]
          span = type == "REASONING_END"
          open = span ? @open_spans : @open_reasoning
          unless open.include?(id)
            if span
              fail!("Cannot send 'REASONING_END' event: No active reasoning span found with ID '#{id}'. A " \
                    "'REASONING_START' event must be sent first.")
            end
            fail!("Cannot send '#{type}' event: No active reasoning message found with ID '#{id}'. Start a reasoning " \
                  "message with 'REASONING_MESSAGE_START' first.")
          end
          check_owner!(type, event["subagentRunId"], :reasoning, "reasoning message", id)
          -> { open.delete(id) } unless type == "REASONING_MESSAGE_CONTENT"
        end

        # Continues an entity by entityId; `subtype` says which kind. "message"
        # spans text and reasoning messages (ids are unique per kind).
        def encrypted_value(event)
          id = event["entityId"]
          bucket, kind = if event["subtype"] == "tool-call"
                           [:tool_call, "tool call"]
                         elsif @owners[:message].key?(id)
                           [:message, "message"]
                         else
                           [:reasoning, "message"]
                         end
          check_owner!("REASONING_ENCRYPTED_VALUE", event["subagentRunId"], bucket, kind, id)
          nil
        end

        # --- steps ---

        # The commit that starts a step, once its owner has no active step of that name.
        def step_started(event)
          name = event["stepName"]
          owner = event["subagentRunId"]
          if @steps.key?(owner) && @steps[owner].include?(name)
            fail!("Step \"#{name}\" is already active for 'STEP_STARTED'#{" in subagent '#{owner}'" unless owner.nil?}")
          end
          -> { @steps[owner] << name }
        end

        # The commit that finishes a step, which only its own owner may do.
        def step_finished(event)
          name = event["stepName"]
          owner = event["subagentRunId"]
          return -> { @steps[owner].delete(name) } if @steps.key?(owner) && @steps[owner].include?(name)

          other = @steps.find { |key, names| key != owner && names.include?(name) }
          if other
            fail!("Cannot send 'STEP_FINISHED' for step \"#{name}\" attributed to #{describe(owner)}: that step is " \
                  "open under #{describe(other.first)}. A step must be finished by whoever started it.")
          end
          fail!("Cannot send 'STEP_FINISHED' for step \"#{name}\" that was not started")
        end

        # An owner as a rejection names it.
        def describe(owner) = owner.nil? ? "the parent agent" : "subagent '#{owner}'"

        # --- activities ---

        # Only a replacing snapshot re-mints (and so re-owns) an activity.
        def activity_snapshot(event)
          id = event["messageId"]
          return unless !@owners[:activity].key?(id) || event["replace"] != false

          -> { @owners[:activity][id] = event["subagentRunId"] }
        end

        # Checks a delta's tag against its activity's owner.
        def activity_delta(event)
          check_owner!("ACTIVITY_DELTA", event["subagentRunId"], :activity, "activity", event["messageId"])
          nil
        end

        # --- subagents ---

        # The commit that activates a subagent, once its id is fresh and its parent known.
        def subagent_started(event)
          id = event["subagentRunId"]
          parent = event["parentSubagentRunId"]
          if @active_subagents.include?(id)
            fail!("Cannot send 'SUBAGENT_STARTED': subagent '#{id}' is already active. Finish it with " \
                  "'SUBAGENT_FINISHED' first.")
          end
          if @closed_subagents.include?(id)
            fail!("Cannot send 'SUBAGENT_STARTED': subagent '#{id}' has already finished in this run. Subagent IDs " \
                  "are per-invocation and cannot be reused.")
          end
          if !parent.nil? && !@active_subagents.include?(parent) && !@closed_subagents.include?(parent)
            fail!("Cannot send 'SUBAGENT_STARTED': parentSubagentRunId '#{parent}' has not been started in this run.")
          end
          -> { @active_subagents << id }
        end

        # The commit that retires an active subagent for the rest of the run.
        def subagent_terminal(event)
          type = event["type"]
          id = event["subagentRunId"]
          unless @active_subagents.include?(id)
            fail!("Cannot send '#{type}': no active subagent found with ID '#{id}'. A 'SUBAGENT_STARTED' event must " \
                  "be sent first.")
          end
          lambda do
            @active_subagents.delete(id)
            @closed_subagents << id
          end
        end

        # --- snapshots and the run ---

        # The ownership bucket a replayed message's role files it under.
        ROLE_BUCKETS = { "reasoning" => :reasoning, "activity" => :activity }.freeze
        private_constant :ROLE_BUCKETS

        # Replayed history seeds ownership like an opener would: a snapshot is
        # authoritative (it replaces), the RUN_STARTED input echo is plain history.
        def seed_owners(messages, authoritative)
          return unless messages.is_a?(Array)

          messages.each do |message|
            next unless message.is_a?(Hash) && message["id"].is_a?(String)

            bucket = ROLE_BUCKETS.fetch(message["role"], :message)
            owner = message["subagentRunId"]
            @owners[bucket][message["id"]] = owner if authoritative || !@owners[bucket].key?(message["id"])
            Array(message["toolCalls"]).each do |call|
              next unless call.is_a?(Hash) && call["id"].is_a?(String)

              @owners[:tool_call][call["id"]] = owner if authoritative || !@owners[:tool_call].key?(call["id"])
            end
          end
        end

        # The commit that seeds ownership from a snapshot, authoritatively.
        def messages_snapshot(event) = -> { seed_owners(event["messages"], true) }

        # The commit that opens the run and seeds ownership from its input history.
        def run_started(event)
          lambda do
            @run_started = true
            seed_owners(event.dig("input", "messages"), false)
          end
        end

        # The commit that closes the run, once nothing is left open.
        def run_finished(_event)
          open_steps = @steps.flat_map do |owner, names|
            names.map do |name|
              owner.nil? ? name : "#{name} (subagent '#{owner}')"
            end
          end
          still_open!("steps", open_steps)
          still_open!("text messages", @open_messages)
          still_open!("reasoning messages", @open_reasoning)
          still_open!("reasoning spans", @open_spans)
          still_open!("tool calls", @open_tool_calls)
          still_open!("subagents", @active_subagents)
          -> { @run_finished = true }
        end

        # Rejects RUN_FINISHED while any entity of a kind is still open.
        def still_open!(what, ids)
          return if ids.empty?

          fail!("Cannot send 'RUN_FINISHED' while #{what} are still active: #{ids.to_a.join(", ")}",
                kind: :open_at_finish)
        end

        # RUN_ERROR may arrive at any time and ends whatever was still open.
        def run_error(_event) = -> { @run_error = true }

        # Raises a verification rejection, with the kind lenient mode recovers by.
        def fail!(message, kind: nil) = raise(ProtocolError.new(message, stage: :verification, kind: kind))
      end
    end
  end
end
