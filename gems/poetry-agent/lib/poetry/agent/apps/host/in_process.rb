# frozen_string_literal: true

require "faraday"
require "rack/mock"

module Poetry
  module Agent
    module Apps
      class Host
        # A Faraday adapter that sends the host's requests into a Rack app in
        # this process: for a host whose server is the application itself
        # (the docs site hosts its own app) and for tests. No socket; the
        # server sees the request it would see over the network (the method,
        # the URL's scheme and host, the headers, the body).
        #
        # @example A host over the application's own server
        #   Poetry::Agent::Apps::Host.new(
        #     servers: { "self" => { url: "https://chat.example/mcp" } }, origin: "https://chat.example",
        #     http_client_customizer: Poetry::Agent::Apps::Host::InProcess.customizer(Rails.application)
        #   )
        class InProcess < Faraday::Adapter
          # The request headers Rack names without the `HTTP_` prefix.
          BARE_HEADERS = %w[CONTENT_TYPE CONTENT_LENGTH].freeze

          # The customizer a host takes for a Rack app: it sets this adapter on the gem's connection.
          #
          # @param rack_app [#call] the Rack application the requests go into
          # @return [Proc] for `http_client_customizer:`
          def self.customizer(rack_app)
            adapter = self
            ->(faraday) { faraday.adapter(adapter, rack_app) }
          end

          # The adapter over a Rack app.
          #
          # @param app [#call] the rest of the Faraday stack (Faraday passes it)
          # @param rack_app [#call] the Rack application
          def initialize(app, rack_app)
            super(app)
            @rack_app = rack_app
          end

          # Runs the request through the Rack app and saves its answer as the response.
          #
          # @param env [Faraday::Env] the request
          # @return [Faraday::Response]
          def call(env)
            super
            response = Rack::MockRequest.new(@rack_app).request(env[:method].to_s.upcase, env[:url].to_s, rack_env(env))
            save_response(env, response.status, response.body, response.headers.to_h)
            @app.call(env)
          end

          private

          # The Rack environment: the body, the URL's host, and the request headers as Rack names them.
          def rack_env(env)
            uri = env[:url]
            body = env[:body]
            rack = { input: body.respond_to?(:read) ? body.read : body.to_s,
                     "HTTP_HOST" => (uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}") }
            env[:request_headers].to_h.each do |name, value|
              key = name.to_s.upcase.tr("-", "_")
              rack[BARE_HEADERS.include?(key) ? key : "HTTP_#{key}"] = value
            end
            rack
          end
        end
      end
    end
  end
end
