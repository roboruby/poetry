# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/lib/fox_tail/stimulus_manager.rb
    module Stimulus
      # Manages multiple Stimulus controllers and their associated HTML attributes.
      #
      # The Manager class provides a registry for Stimulus controllers that need to be
      # attached to a component's HTML attributes. It ensures that each controller is
      # registered only once and provides convenient methods for working with multiple
      # Stimulus builders simultaneously.
      #
      # This is particularly useful in component systems where multiple concerns or
      # behaviors might want to attach Stimulus controllers to the same HTML element,
      # and you need to coordinate and track all registered controllers.
      #
      # @example Basic usage
      #   html_attrs = {}
      #   manager = Poetry::Core::Stimulus::Manager.new(html_attrs)
      #
      #   # Register a dropdown controller
      #   manager.register("dropdown", { open_value: false })
      #
      #   # Register another controller
      #   manager.register("modal")
      #
      #   # Check if a controller is registered
      #   manager.registered?("dropdown") # => true
      #
      #   # Access a specific builder
      #   builder = manager["dropdown"]
      #
      # @example Using aliases
      #   manager << ["tooltip", { position: "top" }]
      #   manager["popover"] = { trigger: "click" }
      class Manager
        # @return [Hash] The HTML attributes hash that all registered builders will modify
        attr_reader :html_attributes

        # Creates a new Stimulus manager for coordinating multiple controllers.
        #
        # @param html_attributes [Hash] The HTML attributes hash that will be modified
        #   by all registered Stimulus builders. This is typically the same hash used
        #   for rendering HTML elements.
        def initialize(html_attributes)
          @html_attributes = html_attributes
          @stimulus_builders = ActiveSupport::HashWithIndifferentAccess.new
        end

        # Registers a new Stimulus controller with the manager.
        #
        # Creates a StimulusBuilder for the given identifier, registers its controller
        # in the HTML attributes, and stores it for later access. Raises an error if
        # a controller with the same identifier has already been registered.
        #
        # @param identifier [String, Symbol] The Stimulus controller identifier
        #   (e.g., "dropdown", "modal", "my-component")
        # @param options [Hash] Options to pass to the StimulusBuilder
        # @return [Poetry::Core::Stimulus::Builder] The newly created and registered builder
        # @raise [KeyError] If a builder with this identifier is already registered
        #
        # @example Register with options
        #   manager.register("dropdown", { open_value: false, position: "bottom" })
        def register(identifier, options = {})
          identifier = Poetry::Core::Stimulus::Builder.format_identifier(identifier)
          raise KeyError, "Stimulus builder '#{identifier}' already registered" if registered?(identifier)

          @stimulus_builders[identifier] = with(identifier, options).tap(&:register_controller)
        end

        alias << register
        alias []= register

        # Creates a new StimulusBuilder without registering it.
        #
        # This method is useful when you want to work with a builder temporarily
        # or configure it before registration.
        #
        # @param identifier [String, Symbol] The Stimulus controller identifier
        # @param options [Hash] Options to pass to the StimulusBuilder
        # @return [Poetry::Core::Stimulus::Builder] A new builder instance
        #
        # @example Create a builder for temporary use
        #   builder = manager.with("tooltip", { text: "Hello" })
        #   builder.add_action("mouseenter", "show")
        def with(identifier, options = {})
          Poetry::Core::Stimulus::Builder.new(identifier, @html_attributes, options)
        end

        # Retrieves a registered Stimulus builder by identifier.
        #
        # @param identifier [String, Symbol] The controller identifier to look up
        # @return [Poetry::Core::Stimulus::Builder, nil] The registered builder, or nil if not found
        #
        # @example Access a registered builder
        #   builder = manager["dropdown"]
        #   builder&.add_action("click", "toggle")
        def [](identifier)
          @stimulus_builders[identifier]
        end

        # Checks if a Stimulus controller is registered with the manager.
        #
        # @param identifier [String, Symbol] The controller identifier to check
        # @return [Boolean] true if the controller is registered, false otherwise
        #
        # @example Check registration status
        #   if manager.registered?("dropdown")
        #     puts "Dropdown controller is registered"
        #   end
        def registered?(identifier)
          identifier = Poetry::Core::Stimulus::Builder.format_identifier(identifier)
          @stimulus_builders.key?(identifier)
        end

        alias key? registered?

        # @!method keys
        #   Returns all registered controller identifiers.
        #   @return [Array<String>] Array of controller identifier strings
        #
        # @!method values
        #   Returns all registered StimulusBuilder instances.
        #   @return [Array<Poetry::Core::Stimulus::Builder>] Array of builder objects
        #
        # @!method each
        #   Iterates over all registered builders.
        #   @yield [identifier, builder] Gives the identifier and builder to the block
        delegate :keys, :values, :each, to: :@stimulus_builders
      end
    end
  end
end
