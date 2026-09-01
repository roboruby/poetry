# frozen_string_literal: true

module Poetry
  module Agent
    # The gem's configuration. Every WebMCP surface is OFF until a rendered
    # instance opts in; the settings here shape delivery and budgets, never
    # exposure.
    class Config
      # Origin-trial tokens the {OriginTrial} middleware serves in the
      # `Origin-Trial` response header (one per browser trial - Chrome and
      # Edge run separate trials). Empty by default: local development
      # enables the API through the browser flag instead.
      #
      # @return [Array<String>]
      attr_accessor :origin_trial_tokens

      def initialize
        @origin_trial_tokens = []
      end

      # The per-page registration budget the registrar enforces: past
      # this many registered tools on one document, further registrations
      # are dropped with a console warning (each tool costs the agent
      # context; overlap confuses tool choice). Stored on poetry-core's
      # configuration, where the component contract reads it to put the
      # budget on every opted-in root - this accessor writes through.
      #
      # @return [Integer]
      def registration_budget
        Poetry::Core::Config.current.webmcp_registration_budget
      end

      # Sets the per-page registration budget.
      #
      # @param count [Integer]
      # @return [Integer]
      def registration_budget=(count)
        Poetry::Core::Config.current.webmcp_registration_budget = Integer(count)
      end

      # The process-wide configuration instance.
      #
      # @return [Config]
      def self.current
        @current ||= new
      end
    end
  end
end
