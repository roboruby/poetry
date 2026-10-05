# frozen_string_literal: true

require "poetry/core"
require "poetry/ui"
require "poetry/lucide"
require "poetry/charts"
require "poetry/agent"
require "poetry/docs/version"
require "poetry/docs/engine"

module Poetry
  # The poetryui.com documentation as a mountable engine.
  module Docs
    # The gem's root directory: the views, the data and the skills the
    # engine serves resolve against it, never against the host's root.
    # @return [Pathname]
    def self.root = Engine.root

    # The Beehiiv publication the subscriptions endpoint posts to. A host
    # sets both in an initializer; absent, the endpoint answers 503.
    class Configuration
      # @return [String, nil] the Beehiiv API key
      attr_accessor :beehiiv_api_key
      # @return [String, nil] the Beehiiv publication id
      attr_accessor :beehiiv_publication_id
    end

    # @return [Configuration]
    def self.config = @config ||= Configuration.new

    # @yield [Configuration]
    def self.configure
      yield config
    end
  end
end
