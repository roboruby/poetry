# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class RegistryAddressTest < Minitest::Test
      def test_the_classification_table
        {
          "https://acme.dev/r/fancy-chart.json" => :url,
          "http://localhost:3000/r/x.json" => :url,
          "./registry/fancy-chart.json" => :file,
          "../shared/item.json" => :file,
          "/tmp/item.json" => :file,
          "items/fancy-chart.json" => :file, # .json suffix wins over bare
          "@acme/fancy-chart" => :namespace,
          "@poetry/button" => :namespace,
          "button" => :bare,
          "Button" => :bare,
          "input_group" => :bare
        }.each do |raw, kind|
          assert_equal kind, RegistryAddress.parse(raw).kind, "#{raw.inspect} should classify as #{kind}"
        end
      end

      def test_names_normalize_to_kebab_everywhere
        assert_equal "input-group", RegistryAddress.parse("InputGroup").name
        assert_equal "input-group", RegistryAddress.parse("input_group").name
        assert_equal "fancy-chart", RegistryAddress.parse("@acme/FancyChart").name
      end

      def test_namespace_parses_registry_and_item
        address = RegistryAddress.parse("@acme/fancy-chart")

        assert_equal "@acme", address.namespace
        assert_equal "fancy-chart", address.name
        assert_predicate address, :remote?
      end

      def test_bare_is_the_only_local_kind
        refute_predicate RegistryAddress.parse("button"), :remote?
        assert_predicate RegistryAddress.parse("./x.json"), :remote?
      end

      def test_malformed_addresses_raise
        ["", "@acme", "@acme/x/y", "@/x", "spaced name"].each do |raw|
          assert_raises(ArgumentError, "#{raw.inspect} should raise") { RegistryAddress.parse(raw) }
        end
      end

      def test_sibling_resolution_follows_the_parent
        assert_equal "@acme/other", RegistryAddress.parse("@acme/fancy-chart").sibling("other").raw
        assert_equal "https://acme.dev/r/other.json",
                     RegistryAddress.parse("https://acme.dev/r/fancy-chart.json").sibling("other").raw
        assert_equal "./registry/other.json",
                     RegistryAddress.parse("./registry/fancy-chart.json").sibling("other").raw
        assert_raises(ArgumentError) { RegistryAddress.parse("button").sibling("other") }
      end
    end
  end
end
