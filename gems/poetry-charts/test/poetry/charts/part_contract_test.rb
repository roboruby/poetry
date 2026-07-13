# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The part-contract tier (the poetry-ui gate, charts-sized):
    # every chart component's declared part contract (Concerns::Parts) is
    # reconciled against the DOM of every preview example, both directions,
    # so the registry-published styling surface (chart-* parts, state
    # attributes, --chart-*/--color-* var seams) can never lie.
    # PART_CONTRACT_ONLY=bar_chart,pie_chart filters for iteration.
    class PartContractTest < ViewComponent::TestCase
      def test_every_component_honors_its_part_contract
        only = ENV["PART_CONTRACT_ONLY"]&.split(",")
        failures = []
        registry_components.each do |component|
          next if only && !only.include?(component.component_title)

          docs = preview_docs(component)
          next if docs.nil? # a component without a preview is the registry gate's problem

          findings = Poetry::Core::PartContract.verify(
            title: component.component_title,
            parts: component.part_definitions,
            docs: docs,
            sources: component_sources(component) + js_corpus
          )
          failures.concat(findings.map { |finding| format_finding(component, finding) })
        end

        assert_empty failures,
                     "#{failures.size} part-contract finding(s):\n\n#{failures.join("\n")}"
      end

      private

      def registry_components
        Poetry::Core::Registry.new(source_root: Poetry::Charts.root).components
      end

      def preview_docs(component)
        preview = component.name.sub(/Component\z/, "Preview").constantize
        preview.examples.map do |example|
          render_preview(example, from: preview)
          rendered_content
        end
      rescue NameError
        nil
      end

      def component_sources(component)
        dir = Poetry::Charts.root.join("app/components", component.component_path)
        Dir.glob("#{dir}/**/*.{rb,erb}").sort.map { |file| File.read(file) }.join("\n")
      end

      # The second source for JS-applied states and vars: charts' own
      # controllers plus core's (motion/live ride core primitives).
      def js_corpus
        @js_corpus ||= [Poetry::Charts.root, Poetry::Core.root].flat_map do |root|
          Dir.glob("#{root.join('app/javascript')}/**/*.js").sort
        end.map { |file| File.read(file) }.join("\n")
      end

      def format_finding(component, finding)
        line = "#{component.component_path}: [#{finding.rule}] #{finding.message}"
        finding.suggestion ? "#{line}\n    #{finding.suggestion}" : line
      end
    end
  end
end
