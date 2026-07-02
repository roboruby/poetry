# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The Ruby<->JS action contract: every Stimulus token
    # a component RENDERS -
    # controller identifiers, action methods, targets - must exist in the
    # controllers manifest introspected from the live JS classes. A
    # controller rename can never silently strand gem-rendered wiring.
    #
    # Registry-driven: every preview example of every registered component
    # is rendered and scanned, so new components are covered automatically
    # (including wiring written WITHOUT the validating Builder).
    class ActionContractTest < ViewComponent::TestCase
      ACTION_TOKEN = /(?:[\w.:@-]+->)?(?<identifier>[\w-]+)#(?<method>\w+)/
      TARGET_ATTR = /data-(?<identifier>[\w-]+?)-target="(?<name>[^"]+)"/

      def test_every_rendered_stimulus_token_exists_in_the_controllers_manifest
        each_rendered_preview do |html, example|
          html.scan(/data-action="([^"]*)"/).flatten.each do |actions|
            actions.scan(ACTION_TOKEN) do
              identifier = Regexp.last_match(:identifier)
              method = Regexp.last_match(:method)
              definition = Poetry::Core::Stimulus::Manifest.definition(identifier)
              next unless definition # host controllers aren't poetry's to validate

              assert_includes definition["methods"], method,
                              "#{example}: data-action references #{identifier}##{method} " \
                              "but the controller has no such method (run `npm run manifest` in poetry-core?)"
            end
          end

          html.scan(TARGET_ATTR) do
            identifier = Regexp.last_match(:identifier)
            name = Regexp.last_match(:name)
            definition = Poetry::Core::Stimulus::Manifest.definition(identifier)
            next unless definition

            assert_includes definition["targets"], name,
                            "#{example}: unknown target #{name.inspect} for #{identifier}"
          end
        end
      end

      def test_every_rendered_poetry_controller_is_known
        each_rendered_preview do |html, example|
          html.scan(/data-controller="([^"]*)"/).flatten.flat_map(&:split).uniq.each do |identifier|
            next unless identifier.start_with?(Poetry::Core::Stimulus::Manifest::POETRY_PREFIX)

            # definition raises UnknownController for a poetry-namespaced
            # identifier missing from the manifest.
            assert Poetry::Core::Stimulus::Manifest.definition(identifier), "#{example}: #{identifier}"
          end
        end
      end

      private

      def each_rendered_preview
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components.each do |component|
          preview = component.module_parent.const_get(:Preview, false)
          preview.examples.each do |example|
            render_preview(example, from: preview)
            yield rendered_content, "#{preview.name}##{example}"
          end
        rescue NameError
          # a component without a preview is caught by the registry gate, not here
        end
      end
    end
  end
end
