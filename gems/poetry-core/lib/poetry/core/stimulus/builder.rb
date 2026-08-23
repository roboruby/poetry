# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/lib/fox_tail/stimulus_builder.rb
    module Stimulus
      # Builder class for constructing Stimulus controller HTML attributes in a Ruby-friendly way.
      #
      # This class provides a clean API for adding Stimulus data attributes to HTML elements
      # without manually constructing attribute strings. It handles:
      # - Controller registration
      # - Values (data passed to controllers)
      # - CSS class references (for Stimulus classes API)
      # - Outlets (connections to other controllers)
      # - Actions (event listeners)
      # - Custom parameters
      #
      # @example Basic usage
      #   builder = Poetry::Core::Stimulus::Builder.new("dropdown", html_attributes)
      #   builder.register_controller
      #   builder.with_value(:open, false)
      #   builder.with_action(:toggle, on: :click)
      #   # Produces: data-controller="dropdown"
      #   #           data-dropdown-open-value="false"
      #   #           data-action="click->dropdown#toggle"
      #
      # @example With initialization options
      #   builder = Poetry::Core::Stimulus::Builder.new("menu", html_attributes,
      #     values: { visible: true },
      #     actions: { show: :mouseenter, hide: :mouseleave },
      #     classes: { active: "bg-blue-500" }
      #   )
      #
      class Builder
        # Event aliases for common event combinations
        # @example Using hover_in alias
        #   with_action(:show, on: :hover_in)
        #   # Expands to both mouseenter and focus events
        EVENT_ALIASES = {
          hover_in: %w[mouseenter focus].freeze,
          hover_out: %w[mouseleave blur].freeze
        }.freeze

        # @return [String] The formatted Stimulus controller identifier
        attr_reader :identifier

        # @return [Object] The HTML attributes object that will be modified
        attr_reader :html_attributes

        # Creates a new Stimulus builder instance
        #
        # @param identifier [String, Symbol, Array] The Stimulus controller identifier(s)
        # @param html_attributes [Object] An object that responds to merge_stimulus! methods
        # @param options [Hash] Optional configurations
        # @option options [Hash] :values Key-value pairs to register as Stimulus values
        # @option options [Hash] :classes Key-value pairs to register as Stimulus classes
        # @option options [Hash] :outlets Key-value pairs to register as Stimulus outlets
        # @option options [Hash] :params Key-value pairs to register as custom params
        # @option options [Hash] :actions Method-event pairs to register as Stimulus actions
        #
        # @example Single controller
        #   Builder.new("dropdown", html_attributes)
        #
        # @example Multiple controllers (namespaced)
        #   Builder.new([:admin, :dropdown], html_attributes)
        #
        # @example With options
        #   Builder.new("modal", html_attributes,
        #     values: { open: false, size: "large" },
        #     actions: { toggle: :click, close: { on: :keydown, at: :window } }
        #   )
        def initialize(identifier, html_attributes, options = {})
          @identifier = format_identifier identifier
          # nil for host-app controllers; poetry-namespaced identifiers are
          # validated against the committed controllers manifest.
          @definition = Manifest.definition(@identifier)
          @html_attributes = html_attributes
          register_values options[:values]
          register_classes options[:classes]
          register_outlets options[:outlets]
          register_params options[:params]
          register_actions options[:actions]
        end

        # Registers this controller in the data-controller attribute
        #
        # @return [void]
        #
        # @example
        #   builder.register_controller
        #   # Adds: data-controller="dropdown"
        def register_controller
          html_attributes.merge_stimulus_controllers!(identifier)
        end

        # Returns the attribute name for a Stimulus target
        #
        # @return [Symbol] The target attribute name (e.g., :dropdown_target)
        #
        # @example
        #   builder.target_attribute_name
        #   # => :dropdown_target
        def target_attribute_name
          key :target
        end

        # Adds a Stimulus value to the HTML attributes
        #
        # Values are used to pass data from HTML to Stimulus controllers.
        #
        # @param name [String, Symbol] The name of the value
        # @param value [Object] The value to set (will be JSON-encoded if necessary)
        # @return [void]
        #
        # @example
        #   builder.with_value(:open, false)
        #   # Adds: data-dropdown-open-value="false"
        def with_value(name, value)
          validate! camelize(name), @definition&.fetch("values", {})&.keys, "value"
          html_attributes.merge_stimulus! key(name, :value) => value
        end

        # Adds a Stimulus target attribute to the HTML attributes
        #
        # @param name [String, Symbol] The target name (snake_case camelizes)
        # @return [void]
        #
        # @example
        #   builder.with_target(:dialog)
        #   # Adds: data-dropdown-target="dialog"
        def with_target(name)
          html_attributes.merge_stimulus! target_attribute_name => target(name)
        end

        # Validates and returns the JS target name
        #
        # @param name [String, Symbol] The target name
        # @return [String] The camelCase target name
        def target(name)
          camelize(name).tap { |js_name| validate! js_name, @definition&.fetch("targets", []), "target" }
        end

        # Adds a Stimulus class reference to the HTML attributes
        #
        # Classes are used to reference CSS classes that the controller can toggle.
        #
        # @param name [String, Symbol] The name of the class reference
        # @param value [String] The CSS class name(s)
        # @return [void]
        #
        # @example
        #   builder.with_class(:active, "bg-blue-500 text-white")
        #   # Adds: data-dropdown-active-class="bg-blue-500 text-white"
        def with_class(name, value)
          html_attributes.merge_stimulus! key(name, :class) => value
        end

        # Adds a Stimulus outlet reference to the HTML attributes
        #
        # Outlets allow one controller to reference and interact with other controllers.
        #
        # @param name [String, Symbol] The name of the outlet
        # @param value [String] The outlet selector
        # @return [void]
        #
        # @example
        #   builder.with_outlet(:modal, ".modal-controller")
        #   # Adds: data-dropdown-modal-outlet=".modal-controller"
        def with_outlet(name, value)
          html_attributes.merge_stimulus! key(format_identifier(name), :outlet) => value
        end

        # Adds a custom parameter attribute
        #
        # @param name [String, Symbol] The parameter name
        # @param value [Object] The parameter value
        # @return [void]
        #
        # @example
        #   builder.with_param(:size, "large")
        #   # Adds: data-dropdown-size-param="large"
        def with_param(name, value)
          html_attributes.merge_stimulus! param_attribute_name(name) => value
        end

        # Returns the attribute name for a parameter
        #
        # @param name [String, Symbol] The parameter name
        # @return [Symbol] The parameter attribute name
        #
        # @example
        #   builder.param_attribute_name(:size)
        #   # => :dropdown_size_param
        def param_attribute_name(name)
          key name, :param
        end

        # Adds a Stimulus action (event listener) to the HTML attributes
        #
        # @param method [String, Symbol] The controller method to call
        # @param on [Symbol, String, Array<Symbol>, nil] The event(s) to listen for
        # @param at [Symbol, String, nil] The event target (e.g., :window, :document)
        # @return [void]
        #
        # @example Basic action
        #   builder.with_action(:toggle, on: :click)
        #   # Adds: data-action="click->dropdown#toggle"
        #
        # @example Multiple events using alias
        #   builder.with_action(:show, on: :hover_in)
        #   # Adds: data-action="mouseenter->dropdown#show focus->dropdown#show"
        #
        # @example Global event
        #   builder.with_action(:close, on: :keydown, at: :window)
        #   # Adds: data-action="keydown@window->dropdown#close"
        def with_action(method, on: nil, at: nil)
          html_attributes.merge_stimulus_actions! action(method, on: on, at: at)
        end

        # Builds a Stimulus action string
        #
        # @param method [String, Symbol] The controller method to call
        # @param on [Symbol, String, Array<Symbol>, nil] The event(s) to listen for
        # @param at [Symbol, String, nil] The event target (e.g., :window, :document)
        # @return [String] The formatted action string
        #
        # @example Simple action
        #   builder.action(:toggle)
        #   # => "dropdown#toggle"
        #
        # @example With event
        #   builder.action(:toggle, on: :click)
        #   # => "click->dropdown#toggle"
        #
        # @example With event target
        #   builder.action(:close, on: :keydown, at: :window)
        #   # => "keydown@window->dropdown#close"
        #
        # @example Multiple events
        #   builder.action(:show, on: [:mouseenter, :focus])
        #   # => "mouseenter->dropdown#show focus->dropdown#show"
        def action(method, on: nil, at: nil)
          js_method = camelize(method)
          validate! js_method, @definition&.fetch("methods", []), "action method"
          controller_method = "#{identifier}##{js_method}"

          if on.nil?
            controller_method
          else
            events = Array(on).map { |event| EVENT_ALIASES.fetch(event, event) }.flatten

            controller_actions = events.each_with_object([]) do |event, actions|
              if event.nil?
                actions << controller_method
              else
                event = "#{event}@#{at}" if at.present?
                actions << "#{event}->#{controller_method}"
              end
            end

            controller_actions.join " "
          end
        end

        # Builds a custom Stimulus event name
        #
        # @param event [String, Symbol] The event name
        # @return [String] The namespaced event name
        #
        # @example
        #   builder.event(:opened)
        #   # => "dropdown:opened"
        #
        # @example Usage in JavaScript
        #   // Dispatch custom event: this.dispatch("opened")
        #   // Listen in HTML: data-action="dropdown:opened->other#handleOpened"
        def event(event)
          "#{identifier}:#{event}"
        end

        private

        delegate :format_identifier, to: :class

        # Ruby snake_case -> Stimulus camelCase (the JS-side name).
        def camelize(name)
          name.to_s.gsub(/_([a-z\d])/) { Regexp.last_match(1).upcase }
        end

        # No-op for host-app controllers (no definition); raises with the
        # known list for poetry controllers - the message IS the fix
        # (agent-teachable failures).
        def validate!(js_name, known, kind)
          return if known.nil? || known.include?(js_name)

          raise Manifest::UnknownName,
                "unknown #{kind} #{js_name.inspect} for #{identifier} - known #{kind}s: #{known.sort.join(", ")}"
        end

        # Builds an attribute key from parts
        #
        # @param parts [Array] The parts to join
        # @return [Symbol] The formatted key
        #
        # @example
        #   key(:open, :value)
        #   # => :dropdown_open_value
        def key(*parts)
          key = parts.map(&:to_s)
          key.unshift identifier
          key.join("_").tr("-", "_").to_sym
        end

        # Registers multiple Stimulus values from a hash
        #
        # @param values [Hash, nil] Hash of name-value pairs
        # @return [void]
        def register_values(values)
          return if values.blank?

          values.each { |name, value| with_value name, value }
        end

        # Registers multiple Stimulus classes from a hash
        #
        # @param classes [Hash, nil] Hash of name-class pairs
        # @return [void]
        def register_classes(classes)
          return if classes.blank?

          classes.each { |name, value| with_class name, value }
        end

        # Registers multiple Stimulus outlets from a hash
        #
        # @param outlets [Hash, nil] Hash of name-outlet pairs
        # @return [void]
        def register_outlets(outlets)
          return if outlets.blank?

          outlets.each { |name, value| with_outlet name, value }
        end

        # Registers multiple custom params from a hash
        #
        # @param params [Hash, nil] Hash of name-param pairs
        # @return [void]
        def register_params(params)
          return if params.blank?

          params.each { |name, value| with_param name, value }
        end

        # Registers multiple Stimulus actions from a hash
        #
        # @param actions [Hash, nil] Hash of method-event pairs
        #   Values can be symbols, arrays, or hashes with :on and :at keys
        # @return [void]
        #
        # @example
        #   register_actions(toggle: :click, close: { on: :keydown, at: :window })
        def register_actions(actions)
          return if actions.blank?

          actions.each do |method, value|
            if value.is_a?(Hash)
              with_action method, **value
            else
              with_action method, on: value
            end
          end
        end

        class << self
          # Formats an identifier by converting underscores to dashes
          #
          # @param identifier [String, Symbol, Array] The identifier(s) to format
          # @return [String] The formatted identifier
          #
          # @example Single identifier
          #   format_identifier(:my_controller)
          #   # => "my-controller"
          #
          # @example Multiple identifiers (namespaced)
          #   format_identifier([:admin, :dropdown])
          #   # => "admin--dropdown"
          def format_identifier(identifier)
            Array(identifier).map { |i| i.to_s.tr("_", "-") }.join("--")
          end
        end
      end
    end
  end
end
