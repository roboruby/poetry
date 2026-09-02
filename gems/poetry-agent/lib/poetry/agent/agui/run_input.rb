# frozen_string_literal: true

require "securerandom"

module Poetry
  module Agent
    module AGUI
      # Builds the `RunAgentInput` wire hash an AG-UI agent accepts:
      # camelCased keys, messages in the protocol's shapes, the
      # frontend-defined tools, context entries, state, forwarded props,
      # and the resume entries that answer interrupts.
      module RunInput
        module_function

        # @param thread_id [String] the conversation thread
        # @param messages [Array<Hash>] protocol messages (`id`, `role`, `content`, ...)
        # @param run_id [String] defaults to a fresh UUID
        # @param tools [Array<Hash>] frontend-defined tools ({AGUI.tool_descriptor})
        # @param context [Array<Hash>] `{ "description", "value" }` entries
        # @param state [Hash] the shared state to send
        # @param forwarded_props [Hash] integration-specific props
        # @param parent_run_id [String, nil] the run this one branches from
        # @param resume [Array<Hash>, nil] `{ "interruptId", "status", "payload" }` answers
        # @return [Hash] the wire hash (string keys)
        # @example A first run with one client tool
        #   RunInput.build(thread_id: "t1", messages: [RunInput.user_message("hi")],
        #                  tools: [Poetry::Agent::AGUI.tool_descriptor("sections", definition)])
        def build( # rubocop:disable Metrics/ParameterLists -- one keyword per RunAgentInput field
          thread_id:, messages:, run_id: SecureRandom.uuid, tools: [], context: [], state: {},
          forwarded_props: {}, parent_run_id: nil, resume: nil
        )
          input = {
            "threadId" => thread_id,
            "runId" => run_id,
            "state" => state,
            "messages" => messages,
            "tools" => tools,
            "context" => context,
            "forwardedProps" => forwarded_props
          }
          input["parentRunId"] = parent_run_id if parent_run_id
          input["resume"] = resume if resume
          input
        end

        # A user message.
        #
        # @param content [String]
        # @param id [String]
        # @return [Hash]
        def user_message(content, id: SecureRandom.uuid)
          { "id" => id, "role" => "user", "content" => content }
        end

        # A tool-result message answering a tool call the browser ran.
        #
        # @param tool_call_id [String]
        # @param content [String] the result as text (JSON for structured results)
        # @param error [String, nil] set when the tool failed
        # @param id [String]
        # @return [Hash]
        def tool_message(tool_call_id, content, error: nil, id: SecureRandom.uuid)
          message = { "id" => id, "role" => "tool", "content" => content.to_s, "toolCallId" => tool_call_id }
          message["error"] = error if error
          message
        end

        # A resume entry answering an interrupt.
        #
        # @param interrupt_id [String]
        # @param status [String, nil] e.g. "approved", "rejected"
        # @param payload [Object, nil]
        # @return [Hash]
        def resume_entry(interrupt_id, status: nil, payload: nil)
          entry = { "interruptId" => interrupt_id }
          entry["status"] = status if status
          entry["payload"] = payload unless payload.nil?
          entry
        end
      end
    end
  end
end
