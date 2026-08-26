# frozen_string_literal: true

module Poetry
  module Agent
    module WebMCP
      # Rack middleware serving the `Origin-Trial` response header on HTML
      # responses, one token per browser trial (Chrome and Edge run
      # separate trials and issue separate tokens). Tokens come from
      # {Poetry::Agent::Config#origin_trial_tokens}; with none configured
      # the middleware is a pass-through, so it is always safe to mount.
      #
      # Local development needs no token: enable the API through the
      # browser flag instead.
      #
      # @example config/application.rb
      #   config.middleware.use Poetry::Agent::WebMCP::OriginTrial
      class OriginTrial
        HEADER = "origin-trial"

        def initialize(app, tokens: nil)
          @app = app
          @tokens = tokens
        end

        def call(env)
          status, headers, body = @app.call(env)
          tokens = (@tokens || Poetry::Agent.config.origin_trial_tokens).compact.reject(&:empty?)
          if tokens.any? && html?(headers)
            existing = headers[HEADER] || headers["Origin-Trial"]
            headers[HEADER] = [existing, *tokens].compact.join(", ")
          end
          [status, headers, body]
        end

        private

        def html?(headers)
          type = headers["content-type"] || headers["Content-Type"]
          type.to_s.include?("text/html")
        end
      end
    end
  end
end
