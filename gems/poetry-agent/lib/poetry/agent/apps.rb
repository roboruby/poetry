# frozen_string_literal: true

require "mcp"
require_relative "apps/fragment"
require_relative "apps/result"
require_relative "apps/document"
require_relative "apps/activity"
require_relative "apps/host"

module Poetry
  module Agent
    # MCP Apps, the author's side: a Rails app's own MCP server (on the
    # official `mcp` gem) serves Poetry-rendered screens as the interactive
    # UI a host such as Claude shows inside its chat. A {Document} is one
    # `ui://` resource, a complete HTML page rendered through the app's own
    # views and layout-free of the host page: Poetry's stylesheet and
    # controllers reach it from the app's origin (or inlined), and the
    # bridge (`@poetry/agent/mcp_app`) speaks the spec's JSON-RPC over
    # postMessage to the host. A tool answers with a {Result}: text for the
    # model, data in `structuredContent`, and {Fragment}s of server-rendered
    # HTML in `_meta`, which the bridge applies by region the way Turbo
    # Streams apply, so the page stays a template and the data stays with
    # the call.
    #
    # The server, the transport, consent, the sandbox and the iframe are the
    # gem's and the host's; what Poetry adds is the document, the fragments
    # and the bridge.
    #
    # @example A plans app
    #   PLANS = Poetry::Agent::Apps::Document.new(uri: "ui://shop/plans", name: "plans",
    #                                             template: "apps/plans", origin: "https://shop.example")
    #   server = MCP::Server.new(name: "shop", capabilities: Poetry::Agent::Apps.capabilities,
    #                            resources: [PLANS.resource])
    #   server.resources_read_handler(&Poetry::Agent::Apps.reader(PLANS))
    #   server.define_tool(name: "show_plans", meta: PLANS.tool_meta) do |team_size: nil|
    #     Poetry::Agent::Apps.result(text: "Three plans; Pro fits #{team_size}.",
    #                                data: { "recommended" => "pro" },
    #                                fragments: [Poetry::Agent::Apps.fragment("plans", partial: "apps/plans/table",
    #                                                                         locals: { team_size: team_size })])
    #   end
    module Apps
      # The key under a result's `_meta` that carries the fragments.
      META_KEY = "poetry"

      module_function

      # Server capabilities declaring tools, resources and the Apps extension.
      #
      # @return [::MCP::Server::Capabilities]
      def capabilities
        ::MCP::Server::Capabilities.new.tap do |capabilities|
          capabilities.support_tools
          capabilities.support_resources
          capabilities.support_extensions(::MCP::Apps.capability)
        end
      end

      # A `resources_read_handler` block answering each document at its URI
      # (an unknown URI answers nothing, as the gem expects).
      #
      # @param documents [Array<Document>] the documents the server serves
      # @return [Proc] `(params) -> [contents]`
      def reader(*documents)
        documents = documents.flatten
        lambda do |params|
          document = documents.find { |candidate| candidate.serves?(params[:uri] || params["uri"]) }
          document ? [document.contents] : []
        end
      end

      # A fragment for one region: the HTML given, or a partial rendered
      # through the renderer.
      #
      # @param target [String] the region (`data-mcp-region`) the fragment applies to
      # @param html [String, nil] the HTML, when already rendered
      # @param partial [String, nil] the partial to render instead
      # @param locals [Hash] the values the partial reads, by name
      # @param action [Symbol, String] replace (the default), append, prepend or remove
      # @param renderer [#render, nil] what renders the partial (see {.renderer})
      # @return [Fragment]
      def fragment(target, html = nil, partial: nil, locals: {}, action: :replace, renderer: nil)
        html = (renderer || self.renderer).render(partial: partial, locals: locals).to_s if partial
        Fragment.new(target: target, html: html, action: action)
      end

      # A tool result: text for the model, data for the host and the model,
      # fragments for the page.
      #
      # @param text [String] the text content block
      # @param data [Hash, nil] `structuredContent`
      # @param fragments [Array<Fragment>] the fragments the bridge applies
      # @param error [Boolean] whether the result is an error
      # @param meta [Hash] more `_meta` entries
      # @return [Result]
      def result(text:, data: nil, fragments: [], error: false, meta: {})
        Result.new(text: text, data: data, fragments: fragments, error: error, meta: meta)
      end

      # The origin of the request being served, for a document whose
      # `origin:` is `:request` (set by {MCP::HTTP} around each request).
      # @return [String, nil]
      def request_origin = Thread.current[:poetry_agent_apps_origin]

      # Serves a block with the request's origin set.
      #
      # @param origin [String] the request's base URL
      # @yield the block the origin applies to
      # @return [Object] the block's value
      def with_request_origin(origin)
        previous = Thread.current[:poetry_agent_apps_origin]
        Thread.current[:poetry_agent_apps_origin] = origin.to_s.delete_suffix("/")
        yield
      ensure
        Thread.current[:poetry_agent_apps_origin] = previous
      end

      # What renders documents and partials when a call names nothing:
      # Action Controller's base renderer, which has Poetry's helpers (they
      # ride on every view) and the app's templates. Set {.renderer=} to the
      # application's own controller for its helpers and layouts, or name a
      # renderer per document or fragment; the gem never names the host.
      #
      # @return [#render]
      def renderer
        @renderer || ::ActionController::Base
      end

      # Sets the default renderer (anything answering `render(**options)`).
      #
      # @param value [#render, nil] the renderer, or nil for the default
      def renderer=(value)
        @renderer = value
      end
    end
  end
end
