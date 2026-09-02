# frozen_string_literal: true

require_relative "a2ui/catalog"

module Poetry
  module Agent
    # The A2UI surface: Google's declarative generative-UI format, where
    # an agent emits a flat component list against a client-owned catalog
    # and the client renders it with its own components. Poetry's
    # registry IS such a catalog once projected into A2UI's JSON Schema
    # shape - {Catalog} does that projection, so any A2UI agent can
    # generate against Poetry's vocabulary and a renderer can validate
    # what arrives against the same document.
    module A2UI
      # The protocol version the projection targets.
      PROTOCOL_VERSION = "1.0"
      # The shared type definitions a catalog may reference.
      COMMON_TYPES = "https://a2ui.org/specification/v1_0/common_types.json#/$defs/"
    end
  end
end
