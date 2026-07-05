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

      # The registry's per-component controllers list (N7 W1) is derived
      # from constants; this asserts it equals what the previews ACTUALLY
      # render as data-controller - so the JS surface poetry check / llms.txt
      # / the MCP server read can never drift from what ships.
      def test_registry_controllers_match_the_rendered_controllers
        registry = Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
        catalog = YAML.load_file(Poetry::Ui.root.join("config/component_registry.yml"), aliases: true)
                      .fetch("components")
        prefix = Poetry::Core::Stimulus::Manifest::POETRY_PREFIX

        rendered = Hash.new { |hash, key| hash[key] = Set.new }
        registry.components.each do |component|
          path = component.component_path
          # The component's OWN preview: Foo::DialogComponent -> Foo::DialogPreview
          # (module_parent's :Preview would render the sibling Command previews).
          preview = component.name.sub(/Component$/, "Preview").safe_constantize
          next unless preview

          preview.examples.each do |example|
            render_preview(example, from: preview)
            rendered_content.scan(/data-controller="([^"]*)"/).flatten.flat_map(&:split).each do |id|
              rendered[path] << id if id.start_with?(prefix)
            end
          end
        end

        documented_by = ->(path) { (catalog.dig(path, "controllers") || []).to_set { |c| c["identifier"] } }
        globally_documented = registry.components.flat_map { |c| documented_by.call(c.component_path).to_a }.to_set

        registry.components.each do |component|
          path = component.component_path
          documented = documented_by.call(path)

          # Every documented controller is actually rendered (no phantom /
          # dead constant listed in the entry).
          phantom = documented - rendered[path]

          assert_empty phantom,
                       "#{path}: registry lists controllers not rendered by its previews #{phantom.to_a} " \
                       "(regenerate with `bin/rake registry:generate`)"

          # Every rendered controller is documented somewhere - either on this
          # entry or on an embedded component's (Toaster renders Toast children,
          # which carry poetry--core--toast under their OWN entry).
          undocumented = rendered[path] - globally_documented

          assert_empty undocumented,
                       "#{path}: renders undocumented controllers #{undocumented.to_a} - a component wires a " \
                       "controller no registry entry declares (add the identifier constant, regenerate)"
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
