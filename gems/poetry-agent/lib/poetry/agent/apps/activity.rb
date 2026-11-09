# frozen_string_literal: true

module Poetry
  module Agent
    module Apps
      # The activity AG-UI's MCP Apps middleware sends when a tool that has
      # an app answers: an `ACTIVITY_SNAPSHOT` whose `activityType` is
      # "mcp-apps" and whose content carries the tool's MCP result, the
      # app's resource uri, the server (its id and the middleware's hash of
      # its configuration) and the tool's input. A host that shows apps
      # fetches the resource through the middleware and renders it in its
      # sandbox; a page without one reads the result's text here, the
      # fallback, which is the text the model read.
      #
      # @example The step a relay renders without a host
      #   activity = Poetry::Agent::Apps::Activity.from(part[:content])
      #   activity.text          # => "Team: $12 a seat, 5+ seats\n..."
      #   activity.resource_uri  # => "ui://shop/plans"
      class Activity
        # The `activityType` the middleware sends.
        TYPE = "mcp-apps"

        # The tool's MCP result: `content`, `structuredContent`, `isError` and `_meta`.
        #
        # @return [Hash]
        attr_reader :result

        # The app's `ui://` resource.
        #
        # @return [String, nil]
        attr_reader :resource_uri

        # The server's id, when its configuration names one.
        #
        # @return [String, nil]
        attr_reader :server_id

        # The middleware's hash of the server's configuration.
        #
        # @return [String, nil]
        attr_reader :server_hash

        # The tool's input.
        #
        # @return [Hash]
        attr_reader :tool_input

        # Whether a transcript part is one of these activities.
        #
        # @param part [Hash, nil] a transcript part
        # @return [Boolean]
        def self.activity?(part)
          part.is_a?(Hash) && part[:kind] == :activity && part[:activity_type] == TYPE
        end

        # Reads an activity's content as the transcript holds it.
        #
        # @param content [Hash, nil] the activity's content, string or symbol keys
        # @return [Activity]
        def self.from(content)
          content = (content.is_a?(Hash) ? content : {}).transform_keys(&:to_s)
          new(result: content["result"], resource_uri: content["resourceUri"], server_id: content["serverId"],
              server_hash: content["serverHash"], tool_input: content["toolInput"])
        end

        # An activity from its parts, each read tolerantly.
        #
        # @param result [Hash, nil] the tool's MCP result
        # @param resource_uri [String, nil] the app's resource
        # @param tool_input [Hash, nil] the tool's input
        # @param server_id [String, nil] the server's id
        # @param server_hash [String, nil] the middleware's hash of the server's configuration
        def initialize(result:, resource_uri: nil, tool_input: nil, server_id: nil, server_hash: nil)
          @result = result.is_a?(Hash) ? result.transform_keys(&:to_s) : {}
          @resource_uri = resource_uri&.to_s
          @server_id = server_id&.to_s
          @server_hash = server_hash&.to_s
          @tool_input = tool_input.is_a?(Hash) ? tool_input : {}
        end

        # The result's content blocks.
        #
        # @return [Array<Hash>]
        def content
          Array(@result["content"]).grep(Hash).map { |block| block.transform_keys(&:to_s) }
        end

        # The result's text: its text blocks joined with newlines, as the
        # middleware reads them for the model; nil when there is none.
        #
        # @return [String, nil]
        def text
          lines = content.select { |block| block["type"] == "text" }.map { |block| block["text"].to_s }
          lines.empty? ? nil : lines.join("\n")
        end

        # The result's `structuredContent`.
        #
        # @return [Object, nil]
        def structured_content
          @result["structuredContent"]
        end

        # Whether the tool failed.
        #
        # @return [Boolean]
        def error?
          @result["isError"] == true
        end
      end
    end
  end
end
