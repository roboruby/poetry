# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The stimulus-contract tier (the poetry-ui gate, charts-sized): every
    # chart component's use_stimulus declarations are reconciled against
    # the DOM of every preview example, both directions - rendered-but-
    # undeclared (the bypass shape) and declared-but-never-rendered (dead
    # wiring / missing preview coverage). Components without previews
    # (adapter_chart, tooltip_layer) are exercised through the family
    # suites instead. STIMULUS_CONTRACT_ONLY=bar_chart filters for
    # iteration.
    class StimulusContractTest < ViewComponent::TestCase
      def test_every_declared_component_honors_its_stimulus_contract
        only = ENV["STIMULUS_CONTRACT_ONLY"]&.split(",")
        covered = 0
        failures = []
        registry_components.each do |component|
          next if component.stimulus_elements.none?
          next if only && !only.include?(component.component_title)

          docs = preview_docs(component)
          next if docs.nil? # a component without a preview is the registry gate's problem

          covered += 1
          findings = Poetry::Core::StimulusContract.verify(component: component, docs: docs)
          failures.concat(findings.map { |finding| format_finding(component, finding) })
        end

        assert_operator covered, :>=, 8, "the eight chart families must be under contract"
        assert_empty failures,
                     "#{failures.size} stimulus-contract finding(s):\n\n#{failures.join("\n")}"
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

      def format_finding(component, finding)
        lines = ["#{component.name}: [#{finding.rule}] #{finding.message}"]
        lines << "  suggestion: #{finding.suggestion}" if finding.suggestion
        lines.join("\n")
      end
    end
  end
end
