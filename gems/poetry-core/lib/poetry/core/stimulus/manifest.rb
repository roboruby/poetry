# frozen_string_literal: true

require "json"

module Poetry
  module Core
    module Stimulus
      # The controllers manifest: the JS-side API surface (targets / values /
      # classes / methods) introspected from the live controller classes in
      # CI (test/javascript/controllers_manifest.test.js, regenerated with
      # `npm run manifest`) and committed at config/controllers_manifest.json.
      #
      # The Builder validates every name it emits against this, so a
      # renamed controller method can never silently strand gem-rendered
      # wiring - the Ruby<->JS seam is guarded at render time.
      #
      # Policy: poetry-namespaced identifiers ("poetry--*") are validated
      # strictly (unknown one raises); host-app controllers are unknown to
      # poetry and pass through unvalidated.
      module Manifest
        # Raised for a poetry-- identifier the manifest does not know.
        class UnknownController < Poetry::Core::Error; end
        # Raised for a target/value/action name the controller's manifest
        # entry does not list.
        class UnknownName < Poetry::Core::Error; end

        # The identifier prefix marking a controller as poetry-owned (and
        # therefore manifest-validated).
        POETRY_PREFIX = "poetry--"

        module_function

        # The merged controller catalog, identifier => definition
        # (`{"targets" =>, "values" =>, "classes" =>, "methods" =>}`),
        # loaded from poetry-core's committed manifest on first read.
        #
        # @return [Hash{String => Hash}]
        def catalog
          @catalog ||= JSON.parse(Poetry::Core.root.join("config/controllers_manifest.json").read)
        end

        # Other poetry gems merge their committed manifests here.
        #
        # @param path [String, Pathname] a committed controllers_manifest.json
        # @return [Hash{String => Hash}] the catalog after the merge
        def register(path)
          catalog.merge!(JSON.parse(File.read(path)))
        end

        # The catalog definition of one controller.
        #
        # @param identifier [String] the full Stimulus identifier
        #   ("poetry--core--popper")
        # @return [Hash, nil] the controller's definition; nil for host-app
        #   (non-poetry) identifiers, which are not poetry's to validate.
        # @raise [UnknownController] for a `poetry--` identifier the catalog
        #   does not know
        def definition(identifier)
          return catalog[identifier] if catalog.key?(identifier)
          return nil unless identifier.start_with?(POETRY_PREFIX)

          raise UnknownController,
                "unknown poetry Stimulus controller #{identifier.inspect} - known: #{catalog.keys.sort.join(", ")}"
        end
      end
    end
  end
end
