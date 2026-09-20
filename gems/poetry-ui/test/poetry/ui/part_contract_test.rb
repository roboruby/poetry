# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The part-contract tier: every registered component's declared
    # part contract (Concerns::Parts) is reconciled against the DOM of
    # every preview example, both directions - rendered-but-undeclared and
    # declared-but-never-rendered - so the registry-published styling
    # surface (parts, state attributes, var seams) can never lie about the
    # anatomy. The contract is proven by rendering, not by key type-checks.
    #
    # Registry-driven like ActionContractTest: new components are covered
    # automatically. PART_CONTRACT_ONLY=button,card filters for iteration;
    # undeclared-part findings carry paste-ready `part` lines.
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
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components
      end

      def preview_docs(component)
        # Name-based, not module_parent.const_get(:Preview): the sibling-
        # file convention (Command::DialogComponent) pairs each component
        # with ITS preview (Command::DialogPreview), never the parent's.
        preview = component.name.sub(/Component\z/, "Preview").constantize
        preview.examples.map do |example|
          render_preview(example, from: preview)
          rendered_content
        end
      rescue NameError
        nil
      end

      def component_sources(component)
        dir = Poetry::Ui.root.join("app/components", component.component_path)
        Dir.glob("#{dir}/**/*.{rb,erb}").map { |file| File.read(file) }.join("\n")
      end

      # The second source for JS-applied states and vars (all poetry
      # controllers live in poetry-core).
      def js_corpus
        @js_corpus ||= Dir.glob("#{Poetry::Core.root.join("app/javascript")}/**/*.js")
                          .map { |file| File.read(file) }.join("\n")
      end

      def format_finding(component, finding)
        line = "#{component.component_path}: [#{finding.rule}] #{finding.message}"
        finding.suggestion ? "#{line}\n    #{finding.suggestion}" : line
      end
    end
  end
end
