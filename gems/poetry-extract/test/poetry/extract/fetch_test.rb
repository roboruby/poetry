# frozen_string_literal: true

require "test_helper"

module Poetry
  module Extract
    class FetchTest < Minitest::Test
      FakeWeb = Struct.new(:styleguide_response, :screenshot_response, :markdown_response) do
        def extract_styleguide(domain:, timeout_ms:)
          raise "missing timeout" unless timeout_ms == Fetch::STYLEGUIDE_TIMEOUT_MS
          raise "missing domain" if domain.to_s.empty?

          styleguide_response
        end

        def screenshot(domain:, full_screenshot:, handle_cookie_popup:)
          raise "upstream params drifted" unless full_screenshot == "false" && handle_cookie_popup == "true"

          { "screenshot" => screenshot_response, "domain" => domain }
        end

        def web_scrape_md(url:, **)
          { "markdown" => markdown_response, "url" => url }
        end
      end

      FakeClient = Struct.new(:web, :brand_payload) do
        def brand = self

        def retrieve(domain:) = { "brand" => brand_payload, "domain" => domain }
      end

      def test_signals_normalize_sdk_payloads_to_plain_string_keyed_data
        web = FakeWeb.new({ "styleguide" => { "mode" => "light", "colors" => { "accent" => "#00f" } } },
                          "https://cdn.example/shot.png", "# Home")
        client = FakeClient.new(web, { "colors" => [{ "hex" => "#635bff", "name" => "Blurple" }] })

        signals = Fetch.signals("example.com", client: client)

        assert_equal "light", signals.styleguide["mode"]
        assert_equal "#635bff", signals.brand["colors"].first["hex"]
        assert_equal "https://cdn.example/shot.png", signals.screenshot_url
        assert_equal "# Home", signals.markdown
      end

      def test_degraded_path_fetches_only_the_homepage
        fetched = []
        signals = Fetch.signals("example.com", client: nil,
                                               homepage_fetcher: ->(d) { (fetched << d) && "plain text" })

        assert_equal ["example.com"], fetched
        assert_nil signals.styleguide
        assert_nil signals.brand
        assert_nil signals.screenshot_url
        assert_equal "plain text", signals.markdown
      end

      def test_default_client_is_nil_without_the_env_key
        original = ENV.delete("CONTEXT_DEV_API_KEY")

        assert_nil Fetch.default_client
      ensure
        ENV["CONTEXT_DEV_API_KEY"] = original if original
      end
    end
  end
end
