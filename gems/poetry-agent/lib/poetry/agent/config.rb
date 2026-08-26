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

      # The per-page registration budget the registrar enforces: past
      # this many registered tools on one document, further registrations
      # are dropped with a console warning (each tool costs the agent
      # context; overlap confuses tool choice).
      #
      # @return [Integer]
      attr_accessor :registration_budget

      def initialize
        @origin_trial_tokens = []
        @registration_budget = 20
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
