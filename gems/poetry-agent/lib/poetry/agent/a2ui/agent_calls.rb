# frozen_string_literal: true

require "digest"
require "json"
require "securerandom"

module Poetry
  module Agent
    module A2UI
      # A session's calls to the agent's functions (A2UI v1.0's
      # `callAgentFunction`): a function a surface calls that no catalog of
      # the renderer implements is sent to the agent, and its value is
      # nothing until the agent's `agentFunctionResponse` arrives.
      #
      # Two kinds of evaluation wait on the agent, and they differ:
      #
      # - A binding or a check rule is evaluated again on every render, so
      #   its calls are shared and kept: identical calls on a surface (the
      #   same catalog, name and resolved arguments) ride one request, a
      #   settled answer serves every later evaluation, and a binding whose
      #   call failed does not send it again until its arguments change. The
      #   id of such a call is derived from the surface, the call and how
      #   many times it has failed, so a session rebuilt from its messages
      #   asks nothing twice: an answer that arrived before the call was made
      #   again is kept in hand and settles it at once.
      # - An action runs once: each of its calls is sent fresh, under an id
      #   of its own, and neither reads nor fills what the surface holds.
      #
      # The session owns one of these when it was built to reach the agent
      # (`Session.new(agent_functions: true)`), hands it to its v1.0
      # surfaces, and sends what gathers in {#outbox}.
      class AgentCalls
        # The codes a call that will never be answered ends with.
        CODES = %w[TIMEOUT CANCELLED DISPOSED DUPLICATE NO_LISTENER].freeze
        # How many answers that match no call are kept in hand, and how many closed ids are remembered.
        KEPT = 256

        # One call to the agent. `state` is `:pending`, `:settled`,
        # `:failed` or `:cancelled`; `error` is the agent's
        # `{ "code", "message" }`, or one of {CODES} with its message.
        Call = Struct.new(:id, :surface_id, :key, :catalog_id, :name, :args, :state, :value, :error, :deadline,
                          :run, :node, :waiters, keyword_init: true) do
          # Whether the call still waits on the agent.
          # @return [Boolean]
          def pending? = state == :pending

          # The `callAgentFunction` message, in the protocol version it is sent in.
          # @param version [String]
          # @return [Hash]
          def message(version)
            function = { "@call" => name, "catalogId" => catalog_id, "args" => args }
            { "version" => version,
              "callAgentFunction" => { "surfaceId" => surface_id, "functionCallId" => id, "callFunction" => function } }
          end
        end

        # One action's evaluation: what each of its calls answered, by the
        # call object as the surface holds it, so a step that already ran is
        # not run again when the action resumes.
        class Run
          # The answers so far, by call object: `[:value, value]`, `[:pending]` or `[:failed, message]`.
          # @return [Hash]
          attr_reader :memo
          # The surface the action runs on.
          # @return [String]
          attr_reader :surface_id

          # A run on a surface, resumed through the block each time one of its calls settles.
          # @param surface_id [String]
          # @param on_cancel [#call, nil] told once when the run is cancelled
          # @yield when a call of the run settles
          def initialize(surface_id, on_cancel: nil, &resume)
            @surface_id = surface_id
            @memo = {}.compare_by_identity
            @resume = resume
            @on_cancel = on_cancel
            @cancelled = false
          end

          # Whether the surface went away, or its calls were cancelled, under the run.
          # @return [Boolean]
          def cancelled? = @cancelled

          # Stops the run: it resumes no more and dispatches nothing.
          # @return [void]
          def cancel!
            return if @cancelled

            @cancelled = true
            @on_cancel&.call
          end

          # Takes the run up again after one of its calls settled.
          # @return [void]
          def resume = (@resume&.call unless @cancelled)
        end

        # The `callAgentFunction` messages waiting to be sent, oldest first; the host takes them as it sends them.
        # @return [Array<Hash>]
        attr_reader :outbox

        # A ledger for one session.
        #
        # @param timeout [Numeric] seconds a call may wait for its answer
        # @param version [String] the protocol version its messages carry
        # @param clock [#call] the time, in seconds, {#expire} compares deadlines with
        # @param on_failure [#call] receives `(call)` when the agent answered with an error or the call timed out
        # @param on_change [#call] receives a surface's id when a binding's call on it got its answer or
        #   failed, so what the surface shows changed
        def initialize(timeout: 30, version: "1.0", clock: nil, on_failure: nil, on_change: nil)
          @timeout = timeout
          @version = version
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
          @on_failure = on_failure
          @on_change = on_change
          @outbox = []
          @pending = {}
          @answers = Hash.new { |held, surface_id| held[surface_id] = {} }
          @flights = Hash.new { |held, surface_id| held[surface_id] = {} }
          @attempts = Hash.new { |held, surface_id| held[surface_id] = Hash.new(0) }
          @failures = Hash.new { |held, surface_id| held[surface_id] = {}.compare_by_identity }
          @in_hand = {}
          @closed = {}
          @disposed = false
        end

        # A binding's or a check rule's call: the surface's answer when it
        # holds one, the binding's own failure when its last attempt failed,
        # else a request, shared with every identical call in flight.
        #
        # @param surface_id [String]
        # @param node [Hash] the call object as the surface holds it, which tells one binding from another
        # @param scope [String, nil] the template scope the binding is evaluated in
        # @param catalog_id [String] the catalog the call resolved to
        # @param name [String]
        # @param args [Hash] the resolved arguments
        # @return [Array] `[:value, value]`, `[:pending]` or `[:failed, message]`
        def reactive(surface_id, node, scope, catalog_id, name, args)
          key = AgentCalls.key(catalog_id, name, args)
          held = @answers[surface_id][key]
          return [:value, held.value] if held

          failed = @failures[surface_id][node]&.[]([scope, key])
          return [:failed, failed.error["message"]] if failed

          flight = @flights[surface_id][key]
          return read(launch(surface_id, key, catalog_id, name, args, [node, scope])) unless flight

          waits = flight.waiters.any? { |waiting, held_scope| waiting.equal?(node) && held_scope == scope }
          flight.waiters << [node, scope] unless waits
          [:pending]
        end

        # An action's call: sent fresh the first time the run reaches it, and what it answered from then on.
        #
        # @param run [Run]
        # @param node [Hash] the call object as the surface holds it
        # @param catalog_id [String]
        # @param name [String]
        # @param args [Hash] the resolved arguments
        # @return [Array] `[:value, value]`, `[:pending]` or `[:failed, message]`
        def imperative(run, node, catalog_id, name, args)
          return run.memo[node] if run.memo.key?(node)

          call = send_call(run.surface_id, AgentCalls.key(catalog_id, name, args), catalog_id, name, args,
                           id: "fn-#{SecureRandom.hex(12)}", run: run, node: node)
          run.memo[node] = read(call)
        end

        # The answer a surface already holds for a call, for a read that cannot wait.
        #
        # @param surface_id [String]
        # @param catalog_id [String]
        # @param name [String]
        # @param args [Hash] the resolved arguments
        # @return [Array, nil] `[:value, value]`, or nil when none has settled
        def held(surface_id, catalog_id, name, args)
          call = @answers[surface_id][AgentCalls.key(catalog_id, name, args)]
          call && [:value, call.value]
        end

        # Sends one call under an id of the caller's choosing and returns
        # it, for a host that calls the agent itself. A call that cannot be
        # made comes back failed: `DUPLICATE` for an id still in flight,
        # `DISPOSED` after {#dispose}.
        #
        # @param surface_id [String]
        # @param catalog_id [String]
        # @param name [String]
        # @param args [Hash] the arguments, already resolved
        # @param id [String, nil] the `functionCallId`; one is made up when nil
        # @param timeout [Numeric, nil] seconds this call may wait; the ledger's when nil
        # @return [Call]
        def call(surface_id:, catalog_id:, name:, args: {}, id: nil, timeout: nil)
          send_call(surface_id, AgentCalls.key(catalog_id, name, args), catalog_id, name, args,
                    id: id || "fn-#{SecureRandom.hex(12)}", timeout: timeout)
        end

        # Settles the call an `agentFunctionResponse` answers. An answer to
        # no call in flight changes nothing that is settled; it is kept in
        # hand, in case a rebuilt session makes that call again.
        #
        # @param body [Hash] the response's body: `functionCallId` with `value` or `error`
        # @return [Call, nil] the call it settled
        def respond(body)
          id = body["functionCallId"]
          call = @pending.delete(id)
          return keep(id, body) unless call

          error = body["error"]
          return fail_call(call, error.is_a?(Hash) ? error : { "message" => error.to_s }) if body.key?("error")

          settle(call, body["value"])
        end

        # Fails every call whose time is up with `TIMEOUT`.
        #
        # @param now [Numeric] the time to compare deadlines with; the clock's when nil
        # @return [Array<Call>] the calls that timed out
        def expire(now = nil)
          now ||= @clock.call
          due = @pending.values.select { |call| call.deadline <= now }
          due.each do |call|
            @pending.delete(call.id)
            fail_call(call, { "code" => "TIMEOUT", "message" => "Agent function '#{call.name}' timed out" })
          end
        end

        # Cancels a surface's calls in flight: each ends `CANCELLED`, with
        # no error reported and nothing remembered, so a binding that is
        # evaluated again asks again; an action waiting on one is dropped.
        #
        # @param surface_id [String]
        # @return [Array<Call>] the calls it cancelled
        def cancel(surface_id)
          gone = @pending.values.select { |call| call.surface_id == surface_id }
          gone.each { |call| drop(call, "CANCELLED", "The surface's agent calls were cancelled") }
        end

        # Forgets a surface that went away: its calls in flight are cancelled and nothing it held is kept.
        #
        # @param surface_id [String]
        # @return [void]
        def forget(surface_id)
          cancel(surface_id)
          [@answers, @flights, @attempts, @failures].each { |held| held.delete(surface_id) }
        end

        # Ends the ledger: every call in flight is cancelled, and a call made afterwards fails `DISPOSED`.
        #
        # @return [Array<Call>] the calls it cancelled
        def dispose
          @disposed = true
          # Over a copy: dropping a call takes it out of the pending ones.
          waiting = @pending.values
          waiting.each { |call| drop(call, "CANCELLED", "The renderer's agent calls were disposed") }
        end

        # The calls still waiting on the agent.
        # @return [Array<Call>]
        def pending = @pending.values

        # A call's identity on a surface: its catalog, its name and its
        # arguments with every object's keys in order, so two spellings of
        # the same arguments are one call.
        #
        # @param catalog_id [String]
        # @param name [String]
        # @param args [Hash]
        # @return [String]
        def self.key(catalog_id, name, args)
          JSON.generate([catalog_id, name, canonical(args)])
        end

        # A value with every object's keys sorted, recursively.
        # @param value [Object]
        # @return [Object]
        def self.canonical(value)
          case value
          when Hash then value.sort_by { |name, _| name.to_s }.to_h { |name, item| [name.to_s, canonical(item)] }
          when Array then value.map { |item| canonical(item) }
          else value
          end
        end

        private

        # A binding's request: under the id its surface, call and failures so far give it, settled at once when its
        # answer is already in hand. The binding that asks is its first waiter.
        def launch(surface_id, key, catalog_id, name, args, waiter)
          attempt = @attempts[surface_id][key] + 1
          id = "fn-#{Digest::SHA256.hexdigest([surface_id, key, attempt].join("\u0000"))[0, 24]}"
          call = send_call(surface_id, key, catalog_id, name, args, id: id, waiters: [waiter])
          @flights[surface_id][key] = call if call.pending?
          call
        end

        # Records a call and queues its message, unless it cannot be made or its answer is in hand.
        def send_call(surface_id, key, catalog_id, name, args, id:, timeout: nil, run: nil, node: nil, waiters: nil) # rubocop:disable Metrics/ParameterLists
          call = Call.new(id: id, surface_id: surface_id, key: key, catalog_id: catalog_id, name: name,
                          args: JSON.parse(JSON.generate(args)), state: :pending, run: run, node: node,
                          waiters: waiters, deadline: @clock.call + (timeout || @timeout))
          refusal = refusal_of(id)
          return close(call, refusal) if refusal

          @pending[id] = call
          early = @in_hand.delete(id)
          early ? respond(early) : @outbox << call.message(@version)
          call
        end

        # Why a call cannot be made: the ledger was disposed, or its id is still in flight.
        def refusal_of(id)
          return { "code" => "DISPOSED", "message" => "The renderer's agent calls were disposed" } if @disposed
          return unless @pending.key?(id)

          { "code" => "DUPLICATE", "message" => "An agent call with functionCallId '#{id}' is already pending" }
        end

        # A call's state as an evaluation reads it.
        def read(call)
          case call.state
          when :pending then [:pending]
          when :settled then [:value, call.value]
          else [:failed, call.error["message"]]
          end
        end

        # A call the agent answered with a value: a binding's is kept for its surface, an action's goes to its run.
        def settle(call, value)
          call.state = :settled
          call.value = value
          finish(call)
          if call.waiters
            @answers[call.surface_id][call.key] = call
            @on_change&.call(call.surface_id)
          end
          call
        end

        # A call the agent answered with an error, or that timed out: reported, and remembered by the bindings that
        # waited on it, so none of them sends it again as it stands.
        def fail_call(call, error)
          call.state = :failed
          call.error = { "code" => error["code"].to_s, "message" => error["message"].to_s }
          finish(call)
          if call.waiters
            @attempts[call.surface_id][call.key] += 1
            call.waiters.each { |node, scope| (@failures[call.surface_id][node] ||= {})[[scope, call.key]] = call }
            @on_change&.call(call.surface_id)
          end
          @on_failure&.call(call) if call.waiters || call.run
          call.run&.resume
          call
        end

        # A call that ends without an answer and without a report.
        def drop(call, code, message)
          @pending.delete(call.id)
          call.state = :cancelled
          call.error = { "code" => code, "message" => message }
          @flights[call.surface_id].delete(call.key) if call.waiters
          call.run&.cancel!
          call
        end

        # A call that was never made.
        def close(call, error)
          call.state = :failed
          call.error = error
          call
        end

        # What every answered call does: leaves the flights, closes its id, and tells its run.
        def finish(call)
          @flights[call.surface_id].delete(call.key) if call.waiters
          remember(@closed, call.id, true)
          return unless call.run

          call.run.memo[call.node] = read(call)
          call.run.resume if call.state == :settled
        end

        # An answer to no call in flight: kept in hand unless its call already closed.
        def keep(id, body)
          remember(@in_hand, id, body) if id.is_a?(String) && !@closed.key?(id)
          nil
        end

        # Keeps a bounded number of entries, the oldest going first.
        def remember(held, key, value)
          held.shift if held.size >= KEPT
          held[key] = value
        end
      end
    end
  end
end
