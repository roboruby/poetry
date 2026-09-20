# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # Raised by assert_poetry_controllers_registered outside Minitest.
      class RegistrationError < StandardError; end

      # The page-wide registration guard behind
      # {Testing#poetry_unregistered_controllers}: every `data-controller`
      # identifier with poetry's prefix must be registered on the host's
      # Stimulus application, or the element is silently inert - Stimulus
      # never errors on an unknown identifier, and one failed import in
      # the controllers graph takes every poetry controller down with it.
      #
      # @api private
      module Registration
        PREFIX = "poetry--"

        # The JS run in the page: `application` is an expression naming
        # the Stimulus application (window.Stimulus in Rails' default
        # controllers/application.js).
        #
        # @return [String]
        def self.script(application)
          <<~JS
            (() => {
              const application = #{application};
              if (!application) return { error: "no Stimulus application at #{application} - the controllers module never ran (one failed import kills the whole graph)" };
              const registry = application.router && application.router.modulesByIdentifier;
              const registered = registry ? Array.from(registry.keys()) : (application.controllers || []).map((c) => c.identifier);
              const known = new Set(registered);
              const missing = new Set();
              for (const element of document.querySelectorAll("[data-controller]")) {
                for (const identifier of element.getAttribute("data-controller").split(/\\s+/)) {
                  if (identifier.startsWith(#{PREFIX.inspect}) && !known.has(identifier)) missing.add(identifier);
                }
              }
              return { missing: Array.from(missing).sort(), registered: registered.filter((id) => id.startsWith(#{PREFIX.inspect})).length };
            })()
          JS
        end

        # The failure text: the identifiers, and the two causes worth
        # checking first.
        #
        # @return [String]
        def self.message(result)
          return result["error"] if result["error"]

          "#{result["missing"].size} poetry controller(s) on the page are not registered on the Stimulus " \
            "application: #{result["missing"].join(", ")} (#{result["registered"]} poetry controllers are). " \
            "Check the importmap pins and that every poetry gem's register call runs in controllers/index.js."
        end
      end
    end
  end
end
