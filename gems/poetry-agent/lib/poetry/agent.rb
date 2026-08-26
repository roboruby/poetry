# frozen_string_literal: true

require "pathname"
require "poetry/core"
require_relative "agent/version"
require_relative "agent/config"
require_relative "agent/mcp/server"
require_relative "agent/webmcp"
require_relative "agent/engine" if defined?(Rails::Engine)

# The poetry namespace.
module Poetry
  # poetry-agent: the agent-interop gem of the poetry family - the
  # surfaces through which agents reach the component contract, built
  # once (the registry) and projected many ways:
  #
  # - {MCP::Server} - the boot-free `poetry-agent` MCP server (discover:
  #   list_components / describe_component / check / compose / build_page
  #   / get_skill) for coding agents in editors.
  # - {WebMCP} - the in-page runtime: rendered components' declared tools
  #   (`tool` declarations in poetry-core) registered with the browser's
  #   `document.modelContext` for the user's own agent (operate), plus the
  #   declarative-form path and the origin-trial delivery.
  #
  # Both read the same committed registries; neither is a second source.
  module Agent
    class << self
      # Gem root (the directory containing lib/, exe/, app/).
      #
      # @return [Pathname]
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # The gem's configuration (origin-trial tokens, registration budget).
      #
      # @return [Poetry::Agent::Config]
      def config
        Config.current
      end

      # Yields the configuration for block-style setup.
      #
      # @yieldparam config [Poetry::Agent::Config]
      # @return [Poetry::Agent::Config]
      # @example config/initializers/poetry_agent.rb
      #   Poetry::Agent.configure do |config|
      #     config.origin_trial_tokens = [ENV["WEBMCP_ORIGIN_TRIAL_TOKEN"]].compact
      #   end
      def configure
        yield config
        config
      end
    end
  end
end
