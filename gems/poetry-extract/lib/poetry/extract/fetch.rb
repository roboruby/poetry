# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Poetry
  module Extract
    # The four design signals for a domain. Any member may be nil - the
    # derivers and the prompt both accept the degraded shape.
    Signals = Struct.new(:styleguide, :brand, :screenshot_url, :markdown, keyword_init: true)

    # The fetch layer. Primary path: the context.dev SDK (the gem's one
    # service dependency - same four calls as upstream). Degraded path (no
    # CONTEXT_DEV_API_KEY): a plain homepage fetch for the markdown signal,
    # nil for the rest - extraction still works, on less evidence.
    module Fetch
      # Styleguide extraction is the slow call - allow it two minutes.
      STYLEGUIDE_TIMEOUT_MS = 120_000

      module_function

      # Fetch the four design signals for a domain. Without a client
      # (CONTEXT_DEV_API_KEY unset) it takes the degraded path: homepage
      # markdown only, every other signal nil.
      #
      # @param domain [String] bare host, e.g. "stripe.com"
      # @param client [Object, nil] the context.dev SDK client; nil selects
      #   the degraded path
      # @param homepage_fetcher [#call] degraded-path fetcher (domain in,
      #   markdown string out)
      # @return [Signals]
      def signals(domain, client: default_client, homepage_fetcher: method(:fetch_homepage))
        return degraded(domain, homepage_fetcher) unless client

        styleguide = client.web.extract_styleguide(domain: domain, timeout_ms: STYLEGUIDE_TIMEOUT_MS)
        brand = client.brand.retrieve(domain: domain)
        screenshot = client.web.screenshot(domain: domain, full_screenshot: "false",
                                           handle_cookie_popup: "true")
        markdown = client.web.web_scrape_md(url: "https://#{domain}", include_links: true,
                                            include_images: false, use_main_content_only: true)

        Signals.new(
          styleguide: normalize(value_of(styleguide, :styleguide)),
          brand: normalize(value_of(brand, :brand)),
          screenshot_url: value_of(screenshot, :screenshot),
          markdown: value_of(markdown, :markdown).to_s
        )
      end

      # The no-client Signals shape: homepage markdown, nothing else.
      # @api private
      def degraded(domain, homepage_fetcher)
        Signals.new(styleguide: nil, brand: nil, screenshot_url: nil,
                    markdown: homepage_fetcher.call(domain).to_s)
      end

      # Build the context.dev SDK client when the API key is present.
      # @api private
      def default_client
        return nil unless ENV["CONTEXT_DEV_API_KEY"]

        require "context_dev"
        ContextDev::Client.new(api_key: ENV.fetch("CONTEXT_DEV_API_KEY"))
      end

      # SDK responses expose the payload as an accessor; plain-hash fakes
      # (tests, cassettes) work identically.
      # @api private
      def value_of(response, key)
        return response[key.to_s] || response[key] if response.is_a?(Hash)

        response.public_send(key)
      end

      # Deep-stringified plain data for the derivers, whatever the SDK's
      # model classes are.
      # @api private
      def normalize(value)
        return nil if value.nil?

        JSON.parse(JSON.generate(value))
      end

      # The degraded markdown signal: the homepage body with tags crudely
      # stripped - supporting evidence for the prompt, never token data.
      # @api private
      def fetch_homepage(domain)
        response = Net::HTTP.get_response(URI("https://#{domain}/"))
        return "" unless response.is_a?(Net::HTTPSuccess)

        response.body.to_s
                .gsub(%r{<(script|style)[^>]*>.*?</\1>}mi, " ")
                .gsub(/<[^>]+>/, " ")
                .gsub(/\s+/, " ")
                .strip
      rescue StandardError
        ""
      end
    end
  end
end
