# frozen_string_literal: true

require "test_helper"

module Poetry
  module Island
    # The island's declared parts match the DOM of its previews, both ways
    # (poetry-ui's PartContractTest, for this gem).
    class PartContractTest < ViewComponent::TestCase
      def test_the_island_honors_its_part_contract
        failures = Poetry::Island.registry.components.flat_map do |component|
          preview = component.name.sub(/Component\z/, "Preview").constantize
          docs = preview.examples.map do |example|
            render_preview(example, from: preview)
            rendered_content
          end
          Poetry::Core::PartContract.verify(title: component.component_title, parts: component.part_definitions,
                                            docs: docs, sources: sources(component))
                                    .map { |finding| "#{component.component_path}: #{finding.message}" }
        end

        assert_empty failures, failures.join("\n")
      end

      private

      def sources(component)
        files = Dir.glob(Poetry::Island.root.join("app/components", component.component_path, "**/*.{rb,erb}"))
        files += Dir.glob(Poetry::Island.root.join("app/javascript/**/*.js"))
        files.map { |file| File.read(file) }.join("\n")
      end
    end
  end
end
