# frozen_string_literal: true

require_relative "a2ui/catalog"
require_relative "a2ui/pointer"
require_relative "a2ui/markdown"
require_relative "a2ui/surface"
require_relative "a2ui/session"
require_relative "a2ui/renderer"
require_relative "a2ui/catalogs/basic"
require_relative "a2ui/catalogs/native"
require_relative "a2ui/streams"

module Poetry
  module Agent
    # The A2UI surface: Google's declarative generative-UI format, where
    # an agent emits a flat component list against a client-owned catalog
    # and the client renders it with its own components. Two halves ship:
    #
    # - {Catalog} projects Poetry's registry into an A2UI v1.0 catalog
    #   document, so any A2UI agent generates against Poetry's vocabulary
    #   and a renderer validates what arrives against the same document.
    # - The renderer: {Session} folds the envelope (`createSurface`,
    #   `updateComponents`, `updateDataModel`, `deleteSurface`) into
    #   {Surface}s, {Renderer} renders a surface through the host's view
    #   context with a catalog binding ({Catalogs::Basic} for the spec's
    #   basic catalog, {Catalogs::Native} for Poetry's own), {Streams}
    #   delivers changes as versioned Turbo Streams, and a submitted
    #   surface form becomes the spec's `action` message
    #   ({Session#action}).
    module A2UI
      # The protocol version the projection targets.
      PROTOCOL_VERSION = "1.0"
      # The shared type definitions a catalog may reference.
      COMMON_TYPES = "https://a2ui.org/specification/v1_0/common_types.json#/$defs/"

      # The catalog bindings a {Session} starts with: the spec's basic
      # catalog and Poetry's own, keyed by catalog id.
      #
      # @return [Hash{String => Object}]
      def self.catalogs
        { Catalogs::Basic::ID => Catalogs::Basic.new, Catalog::DEFAULT_ID => Catalogs::Native.new }
      end
    end
  end
end
