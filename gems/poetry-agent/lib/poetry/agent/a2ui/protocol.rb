# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # The protocol version the projection targets.
      PROTOCOL_VERSION = "1.0"
      # The shared type definitions a catalog references, relative to the
      # catalog, as v1.0's catalogs write them.
      COMMON_TYPES = "common_types.json#/$defs/"
      # Where v0.9's shared type definitions live (a v0.9 catalog names them absolutely).
      COMMON_TYPES_V0_9 = "https://a2ui.org/specification/v0_9/common_types.json#/$defs/"
    end
  end
end
