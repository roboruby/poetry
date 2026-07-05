# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The registry drift gate in the default suite (the poetry-ui pattern):
    # the committed component_registry.yml must match a fresh introspection,
    # and the whole family surface must be present - the file poetry check /
    # llms.txt / poetry-agent project from.
    class RegistryTest < ActiveSupport::TestCase
      def registry
        Rails.application.eager_load!
        Poetry::Core::Registry.new(source_root: Poetry::Charts.root)
      end

      def test_the_committed_registry_matches_a_fresh_build
        assert_predicate registry, :verified?,
                         "stale component registry - run `bin/rake registry:generate` and commit"
      end

      def test_every_chart_family_is_registered
        components = YAML.safe_load_file(Poetry::Charts.root.join("config/component_registry.yml"))
                         .fetch("components").keys

        %w[area_chart line_chart bar_chart pie_chart radial_bar_chart radar_chart
           adapter_chart container tooltip_content legend_content].each do |name|
          assert_includes components, "poetry/charts/#{name}"
        end
      end
    end
  end
end
