# frozen_string_literal: true

module Poetry
  module Docs
    require "net/http"

    # Server-side client for the beehiiv v2 API. The landing page's subscribe
    # dialog posts to SubscriptionsController, which calls this - the key never
    # reaches the browser and the page carries no third-party script.
    module Beehiiv
      # The poetry publication; a host points the engine at another through
      # Poetry::Docs.configure, or the BEEHIIV_* environment.
      PUBLICATION_ID = "pub_5bd5fe45-3605-4ec2-b196-6a7a901a58e2"

      Error = Class.new(StandardError)

      def self.api_key
        Poetry::Docs.config.beehiiv_api_key.presence || ENV["BEEHIIV_API_KEY"].presence
      end

      def self.publication_id
        Poetry::Docs.config.beehiiv_publication_id.presence || ENV["BEEHIIV_PUBLICATION_ID"].presence ||
          PUBLICATION_ID
      end

      def self.endpoint
        URI("https://api.beehiiv.com/v2/publications/#{publication_id}/subscriptions")
      end

      def self.configured?
        api_key.present?
      end

      # Creates (or knowingly reactivates) a subscription. Double opt-in follows
      # the publication's own setting, so the confirm email flow matches the
      # hosted form's behavior.
      def self.subscribe(email:, referring_site: nil)
        raise Error, "beehiiv API key is not configured" unless configured?

        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Post.new(endpoint.path,
                                      "Content-Type" => "application/json",
                                      "Authorization" => "Bearer #{api_key}")
        request.body = {
          email: email,
          reactivate_existing: true,
          send_welcome_email: true,
          utm_source: "poetryui.com",
          utm_medium: "website",
          utm_campaign: "landing_subscribe_dialog",
          referring_site: referring_site
        }.compact.to_json

        response = http.request(request)
        raise Error, "beehiiv responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        true
      end
    end
  end
end
