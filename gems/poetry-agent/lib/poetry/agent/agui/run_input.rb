# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module Poetry
  module Agent
    module AGUI
      # Builds the `RunAgentInput` wire hash an AG-UI agent accepts:
      # camelCased keys, the protocol version this client speaks, messages
      # in the protocol's shapes, the frontend-defined tools, context
      # entries, state, forwarded props, and the resume entries that answer
      # interrupts.
      module RunInput
        # The resume statuses AG-UI 1.0 defines: the interrupt was answered
        # (`resolved`, the answer in the payload) or abandoned (`cancelled`).
        RESUME_STATUSES = %w[resolved cancelled].freeze

        module_function

        # A RunAgentInput hash from its fields, with a generated run id by default.
        # @param thread_id [String] the conversation thread
        # @param messages [Array<Hash>] protocol messages (`id`, `role`, `content`, ...)
        # @param run_id [String] defaults to a fresh UUID
        # @param tools [Array<Hash>] frontend-defined tools ({AGUI.tool_descriptor})
        # @param context [Array<Hash>] `{ "description", "value" }` entries
        # @param state [Object] the shared state to send
        # @param forwarded_props [Hash] integration-specific props
        # @param parent_run_id [String, nil] the run this one branches from
        # @param resume [Array<Hash>, nil] {.resume_entry} answers to the last run's interrupts
        # @param interrupts [Array<Hash>] the thread's open interrupts ({Transcript#interrupts}):
        #   the resume list must cover every one, and may only cancel an expired one
        # @param protocol_version [String, nil] the declared version; nil omits it, for an agent
        #   known to predate the field
        # @return [Hash] the wire hash (string keys)
        # @raise [ProtocolError] for a resume list that leaves an open interrupt uncovered or
        #   answers an expired one: AG-UI 1.0 has the consumer refuse it before anything is sent
        # @example A first run with one client tool
        #   RunInput.build(thread_id: "t1", messages: [RunInput.user_message("hi")],
        #                  tools: [Poetry::Agent::AGUI.tool_descriptor("sections", definition)])
        # @example Answering the interrupts the last run ended with
        #   RunInput.build(thread_id: "t1", messages: transcript.messages_for_input,
        #                  interrupts: transcript.interrupts,
        #                  resume: [RunInput.resume_entry(id, status: "resolved", payload: { "approved" => true })])
        def build( # rubocop:disable Metrics/ParameterLists -- one keyword per RunAgentInput field
          thread_id:, messages:, run_id: SecureRandom.uuid, tools: [], context: [], state: {},
          forwarded_props: {}, parent_run_id: nil, resume: nil, interrupts: [], protocol_version: PROTOCOL_VERSION
        )
          check_resume(interrupts, resume || [])
          input = { "threadId" => thread_id, "runId" => run_id }
          input["protocolVersion"] = protocol_version if protocol_version
          input.merge!("state" => state, "messages" => messages, "tools" => tools, "context" => context,
                       "forwardedProps" => forwarded_props)
          input["parentRunId"] = parent_run_id if parent_run_id
          input["resume"] = resume if resume
          input
        end

        # Whether an interrupt's `expiresAt` has passed. The field's format is
        # left open by the spec; this reads it as ISO 8601, and an interrupt
        # whose value does not parse as one has not expired.
        #
        # @param interrupt [Hash] an interrupt as {Transcript#interrupts} holds it
        # @param now [Time]
        # @return [Boolean]
        def expired?(interrupt, now: Time.now)
          expires_at = interrupt["expiresAt"]
          return false unless expires_at.is_a?(String)

          Time.iso8601(expires_at) <= now
        rescue ArgumentError
          false
        end

        # Refuses a resume list that leaves an open interrupt uncovered (omission
        # is not abandonment) or resolves one that expired (it can still be
        # cancelled, which is how a thread moves past it).
        def check_resume(interrupts, resume)
          answered = resume.to_h { |entry| [entry["interruptId"], entry] }
          uncovered = interrupts.map { |interrupt| interrupt["id"] }.reject { |id| answered.key?(id) }
          if uncovered.any?
            raise ProtocolError.new("The thread has #{uncovered.size} open interrupt(s) the resume list does not " \
                                    "answer: #{uncovered.join(", ")}", stage: :input, kind: :uncovered_interrupt)
          end

          interrupts.each do |interrupt|
            next unless expired?(interrupt) && answered[interrupt["id"]]["status"] != "cancelled"

            raise ProtocolError.new("Interrupt #{interrupt["id"]} expired at #{interrupt["expiresAt"]} and can no " \
                                    "longer be answered; cancel it to continue the thread",
                                    stage: :input, kind: :expired_interrupt)
          end
        end
        private_class_method :check_resume

        # A user message: text, or a list of content parts.
        #
        # @param content [String, Array<Hash>] the text, or content parts (`{ "type" => "text", "text" => ... }`
        #   and image, audio, video or document parts with a `source`)
        # @param id [String]
        # @return [Hash]
        # @example An image beside the question
        #   RunInput.user_message([{ "type" => "text", "text" => "What is this?" },
        #                          { "type" => "image", "source" => { "type" => "url", "value" => url } }])
        def user_message(content, id: SecureRandom.uuid)
          { "id" => id, "role" => "user", "content" => content }
        end

        # A tool-result message answering a tool call the browser ran.
        #
        # @param tool_call_id [String]
        # @param content [String, Array<Hash>, Object] the result: text, a list of content parts, or
        #   data (sent as JSON)
        # @param error [String, nil] set when the tool failed
        # @param id [String]
        # @return [Hash]
        def tool_message(tool_call_id, content, error: nil, id: SecureRandom.uuid)
          content = JSON.generate(content) unless content.is_a?(String) || content.is_a?(Array)
          message = { "id" => id, "role" => "tool", "content" => content, "toolCallId" => tool_call_id }
          message["error"] = error if error
          message
        end

        # A resume entry answering an interrupt.
        #
        # @param interrupt_id [String]
        # @param status [String] "resolved" (answered, the answer in the payload) or "cancelled" (abandoned)
        # @param payload [Object, nil] the answer
        # @return [Hash]
        # @raise [ArgumentError] for a status AG-UI does not define
        # @example Approving an approval interrupt
        #   RunInput.resume_entry(interrupt["id"], status: "resolved", payload: { "approved" => true })
        def resume_entry(interrupt_id, status:, payload: nil)
          unless RESUME_STATUSES.include?(status.to_s)
            raise ArgumentError,
                  "resume status #{status.inspect} is not one of #{RESUME_STATUSES.join(", ")} (AG-UI 1.0)"
          end

          entry = { "interruptId" => interrupt_id, "status" => status.to_s }
          entry["payload"] = payload unless payload.nil?
          entry
        end
      end
    end
  end
end
