# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class RegistryClientTest < Minitest::Test
      VALID_ITEM = {
        "name" => "fancy-chart", "type" => "registry:component",
        "files" => [{ "path" => "app/components/acme/fancy_chart.rb", "content" => "class FancyChart; end\n" }]
      }.freeze

      def build_client(registries: {}, directory: nil, base_dir: Dir.pwd, responses: {})
        requests = []
        fetcher = lambda do |url, headers|
          requests << [url, headers]
          responses.fetch(url) { raise "unstubbed fetch: #{url}" }
        end
        [RegistryClient.new(registries: registries, directory: directory,
                            base_dir: base_dir, fetcher: fetcher), requests]
      end

      def test_namespace_expands_the_url_template
        client, requests = build_client(
          registries: { "@acme" => "https://acme.dev/r/{name}.json" },
          responses: { "https://acme.dev/r/fancy-chart.json" => JSON.generate(VALID_ITEM) }
        )
        item = client.resolve(RegistryAddress.parse("@acme/fancy-chart"))

        assert_equal "fancy-chart", item["name"]
        assert_equal ["https://acme.dev/r/fancy-chart.json", {}], requests.first
      end

      def test_headers_expand_env_placeholders_and_never_leak_into_config
        ENV["POETRY_TEST_TOKEN"] = "sekret"
        client, requests = build_client(
          registries: { "@corp" => { "url" => "https://r.corp.dev/{name}.json",
                                     "headers" => { "Authorization" => "Bearer ${POETRY_TEST_TOKEN}" } } },
          responses: { "https://r.corp.dev/fancy-chart.json" => JSON.generate(VALID_ITEM) }
        )
        client.resolve(RegistryAddress.parse("@corp/fancy-chart"))

        assert_equal({ "Authorization" => "Bearer sekret" }, requests.first.last)
      ensure
        ENV.delete("POETRY_TEST_TOKEN")
      end

      def test_a_missing_env_variable_fails_before_any_request
        client, requests = build_client(
          registries: { "@corp" => { "url" => "https://r.corp.dev/{name}.json",
                                     "headers" => { "Authorization" => "${POETRY_TEST_ABSENT}" } } }
        )
        error = assert_raises(RegistryClient::Error) { client.resolve(RegistryAddress.parse("@corp/x")) }

        assert_match(/POETRY_TEST_ABSENT/, error.message)
        assert_empty requests
      end

      def test_unknown_namespace_resolves_through_the_directory
        directory = { "registries" => { "@acme" => "https://acme.dev/r/{name}.json" } }
        client, requests = build_client(
          directory: "https://registry.example/registries.json",
          responses: { "https://registry.example/registries.json" => JSON.generate(directory),
                       "https://acme.dev/r/fancy-chart.json" => JSON.generate(VALID_ITEM) }
        )
        item = client.resolve(RegistryAddress.parse("@acme/fancy-chart"))

        assert_equal "fancy-chart", item["name"]
        assert_equal 2, requests.size
      end

      def test_unknown_namespace_without_a_directory_names_the_fix
        client, = build_client
        error = assert_raises(RegistryClient::Error) { client.resolve(RegistryAddress.parse("@acme/x")) }

        assert_match(%r{registries: section of config/poetry_components\.yml}, error.message)
      end

      def test_plain_http_is_localhost_only
        client, = build_client(responses: { "http://evil.example/x.json" => JSON.generate(VALID_ITEM) })
        error = assert_raises(RegistryClient::Error) do
          client.resolve(RegistryAddress.parse("http://evil.example/x.json"))
        end

        assert_match(/must be https/, error.message)
      end

      def test_file_addresses_resolve_relative_to_base_dir
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "item.json"), JSON.generate(VALID_ITEM))
          client, = build_client(base_dir: dir)

          assert_equal "fancy-chart", client.resolve(RegistryAddress.parse("./item.json"))["name"]
        end
      end

      def test_items_are_schema_validated
        bad = [
          { "type" => "registry:component" },                                    # no name
          { "name" => "X BAD", "type" => "registry:component" },                 # bad name
          { "name" => "x", "type" => "widget" },                                 # bad type
          { "name" => "x", "type" => "registry:component", "files" => "nope" },  # files not array
          { "name" => "x", "type" => "registry:component",
            "files" => [{ "path" => "a.rb" }] },                                 # file without content
          { "name" => "x", "type" => "registry:component",
            "registryDependencies" => [1] }                                      # non-string dep
        ]
        bad.each_with_index do |item, index|
          client, = build_client(responses: { "https://acme.dev/x.json" => JSON.generate(item) })
          assert_raises(RegistryClient::Error, "item #{index} should fail validation") do
            client.resolve(RegistryAddress.parse("https://acme.dev/x.json"))
          end
        end
      end

      def test_oversized_payloads_are_refused
        client, = build_client(responses: { "https://acme.dev/x.json" => "x" * (RegistryClient::MAX_BYTES + 1) })
        error = assert_raises(RegistryClient::Error) do
          client.resolve(RegistryAddress.parse("https://acme.dev/x.json"))
        end

        assert_match(/byte item cap/, error.message)
      end

      def test_bare_addresses_are_not_the_clients_business
        client, = build_client
        assert_raises(RegistryClient::Error) { client.resolve(RegistryAddress.parse("button")) }
      end
    end
  end
end
