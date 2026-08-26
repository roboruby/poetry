# frozen_string_literal: true

require_relative "webmcp/origin_trial"

module Poetry
  module Agent
    # The WebMCP runtime's Ruby side. The contract itself lives in
    # poetry-core (the `tool` declarations, their registry projection, and
    # the per-instance `webmcp:` payload a component root carries); this
    # module owns what only the runtime gem knows: the Stimulus controller
    # identifiers the JS registers, the controllers manifest that lets
    # core's attribute builder validate them, and origin-trial delivery.
    #
    # Nothing here exposes a tool by itself - a rendered instance opts in
    # (`webmcp: "country"` on the helper call), and the registrar
    # controller registers that instance's declared tools with
    # `document.modelContext` on connect, aborting them on disconnect.
    module WebMCP
      # The registrar controller: reads a root's payload and registers
      # its tools, dispatching each to the component's own controller.
      CONTROLLER = "poetry--agent--webmcp"
      # The declarative-form controller: answers an agent-invoked submit
      # with the form's outcome through `SubmitEvent.respondWith`.
      FORM_CONTROLLER = "poetry--agent--webmcp-form"

      # The committed controllers manifest (the JS surface of the two
      # controllers), merged into poetry-core's catalog by the engine so
      # use_stimulus / the Builder validate poetry--agent--* names exactly
      # like core's own.
      #
      # @return [Pathname]
      def self.manifest_path
        Poetry::Agent.root.join("config/controllers_manifest.json")
      end
    end
  end
end
