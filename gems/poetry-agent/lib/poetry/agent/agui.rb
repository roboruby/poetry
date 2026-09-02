# frozen_string_literal: true

require_relative "agui/json_patch"
require_relative "agui/sse"
require_relative "agui/run_input"
require_relative "agui/client"
require_relative "agui/transcript"
require_relative "agui/turbo_stream"
require_relative "agui/relay"

module Poetry
  module Agent
    # The AG-UI surface: a Rails-side CLIENT of the Agent-User Interaction
    # protocol. An agent backend (any AG-UI integration, or a Ruby server)
    # streams events - text deltas, tool calls, state, activities, run
    # lifecycle, interrupts - and this module turns that stream into
    # server-rendered chat frames a Hotwire page updates through Turbo
    # Streams, the same pipeline the chat replay rig proves.
    #
    # The pieces, each usable alone:
    #
    # - {SSE} parses `text/event-stream` chunks into event hashes.
    # - {Client} POSTs a run to an AG-UI endpoint and yields its events.
    # - {RunInput} builds the `RunAgentInput` wire hash, and
    #   {.tool_descriptor} advertises a rendered component's declared
    #   tools as frontend-defined tools the browser executes.
    # - {Transcript} folds events into messages (Chat-shaped parts),
    #   shared state (JSON Patch), activities, the run status, pending
    #   client tools, and interrupts.
    # - {Relay} renders each change as a versioned Turbo Stream through a
    #   host-supplied row renderer, plus the client-tool bridge element
    #   the `poetry--agent--agui-client-tool` controller executes.
    #
    # Nothing here calls a model: the agent is whatever the host points
    # the client at.
    module AGUI
      # The AG-UI event types this transcript understands (the wire
      # strings; deprecated THINKING_* aliases included).
      EVENT_TYPES = %w[
        RUN_STARTED RUN_FINISHED RUN_ERROR STEP_STARTED STEP_FINISHED
        TEXT_MESSAGE_START TEXT_MESSAGE_CONTENT TEXT_MESSAGE_END TEXT_MESSAGE_CHUNK
        REASONING_START REASONING_MESSAGE_START REASONING_MESSAGE_CONTENT REASONING_MESSAGE_END
        REASONING_MESSAGE_CHUNK REASONING_END REASONING_ENCRYPTED_VALUE
        THINKING_START THINKING_TEXT_MESSAGE_START THINKING_TEXT_MESSAGE_CONTENT THINKING_TEXT_MESSAGE_END THINKING_END
        TOOL_CALL_START TOOL_CALL_ARGS TOOL_CALL_END TOOL_CALL_CHUNK TOOL_CALL_RESULT
        STATE_SNAPSHOT STATE_DELTA MESSAGES_SNAPSHOT ACTIVITY_SNAPSHOT ACTIVITY_DELTA
        SUBAGENT_STARTED SUBAGENT_FINISHED SUBAGENT_ERROR RAW CUSTOM
      ].freeze

      # The frontend-defined tool descriptor for one of a rendered
      # component's declared tools: the MCP `Tool` shape the registry
      # projects, renamed to AG-UI's `parameters` and prefixed with the
      # instance name exactly as the WebMCP registrar registers it, so a
      # call the agent makes is executable in the browser by name.
      #
      # @param instance [String] the `webmcp:` instance name
      # @param definition [Hash] one entry of `Component#webmcp_tools`
      # @return [Hash] `{ "name", "description", "parameters" }`
      # @example
      #   Poetry::Agent::AGUI.tool_descriptor("sections", tabs.webmcp_tools.first)
      #   # => { "name" => "poetry.sections.set_value", "description" => "...", "parameters" => {...} }
      def self.tool_descriptor(instance, definition)
        {
          "name" => "poetry.#{instance}.#{definition["name"]}",
          "description" => definition["description"],
          "parameters" => definition["inputSchema"] || { "type" => "object", "properties" => {} }
        }
      end

      # Reads a wire field from an event or message that may arrive
      # camelCased (the protocol) or snake_cased (a Ruby producer).
      #
      # @param hash [Hash]
      # @param name [String] the camelCase name
      # @return [Object, nil]
      def self.field(hash, name)
        return nil unless hash.is_a?(Hash)

        snake = name.gsub(/([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }
        [name, snake, name.to_sym, snake.to_sym].each do |key|
          return hash[key] if hash.key?(key)
        end
        nil
      end
    end
  end
end
