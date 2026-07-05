# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The action-contract gate (the poetry-ui pattern, charts-sized):
    # render every preview example and validate every rendered
    # poetry--charts-* data-action / data-controller / target token against
    # config/controllers_manifest.json (committed by `npm run manifest`,
    # self-drift-gated by the vitest suite). The Ruby<->JS seam stays
    # guarded end to end.
    class ActionContractTest < ViewComponent::TestCase
      MANIFEST = JSON.parse(Poetry::Charts.root.join("config/controllers_manifest.json").read)

      def charts_previews
        ViewComponent::Preview.all.select { |klass| klass.name&.start_with?("Poetry::Charts::") }
      end

      def test_every_rendered_token_exists_in_the_manifest
        pages = 0

        charts_previews.each do |preview|
          preview.examples.each do |example|
            html = render_preview(example, from: preview)
            pages += 1

            html.css("[data-controller]").each do |node|
              node["data-controller"].split.each do |identifier|
                next unless identifier.start_with?("poetry--charts--")

                assert MANIFEST.key?(identifier), "unknown controller #{identifier}"
              end
            end

            html.css("[data-action]").each do |node|
              node["data-action"].split.each do |token|
                identifier, method = token.split("->").last.split("#")
                next unless identifier&.start_with?("poetry--charts--")

                assert MANIFEST.key?(identifier), "unknown controller #{identifier} in #{token}"
                assert_includes MANIFEST[identifier]["methods"], method,
                                "#{identifier} has no method #{method} (token #{token})"
              end
            end

            MANIFEST.each_key do |identifier|
              html.css("[data-#{identifier}-target]").each do |node|
                node["data-#{identifier}-target"].split.each do |target|
                  assert_includes MANIFEST[identifier]["targets"], target,
                                  "#{identifier} has no target #{target}"
                end
              end
            end
          end
        end

        assert_operator pages, :>=, 20, "the preview corpus rendered"
      end
    end
  end
end
