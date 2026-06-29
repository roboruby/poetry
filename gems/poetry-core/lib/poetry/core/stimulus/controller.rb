# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/app/components/fox_tail/concerns/stimulated.rb
    module Stimulus
      # Represents a Stimulus controller configuration for a ViewComponent.
      #
      # The Controller class encapsulates the metadata and logic for conditionally
      # registering Stimulus controllers with ViewComponents. It handles:
      # - Controller identifier normalization
      # - Method name generation for component access
      # - Conditional registration based on component state
      # - Configuration block management
      #
      # This class is typically used internally by the Stimulus concern when you
      # call `stimulated_with` in a component class to declare Stimulus controllers.
      #
      # @example Basic usage in a component
      #   class MyComponent < ViewComponent::Base
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     stimulated_with :dropdown do |builder|
      #       builder.with_value(:open, false)
      #     end
      #   end
      #
      # @example With conditional registration
      #   class AlertComponent < ViewComponent::Base
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     stimulated_with :dismissable,
      #       if: :dismissable?,
      #       as: :close_controller do |builder|
      #       builder.with_value(:dismiss_after, 5000)
      #     end
      #
      #     def dismissable?
      #       @dismissable == true
      #     end
      #   end
      #
      # @example With custom method name
      #   stimulated_with :dropdown, as: :menu do |builder|
      #     # Accessible via menu_controller method in the component
      #     builder.with_action(:toggle, on: :click)
      #   end
      #
      # @see Poetry::Core::Stimulus::Builder
      # @see Poetry::Core::Stimulus::Manager
      class Controller
        # @return [String] The normalized Stimulus controller identifier (e.g., "my-controller")
        attr_reader :identifier

        # @return [Hash] Controller-specific options (:as, :register, :if, :unless)
        attr_reader :options

        # @return [Hash] Options to pass to the Builder (values, actions, classes, etc.)
        attr_reader :controller_options

        # @return [Proc, nil] Optional configuration block for the builder
        attr_reader :block

        # Creates a new Stimulus controller configuration.
        #
        # @param identifier [String, Symbol, Array] The controller identifier(s)
        #   Will be normalized to use dashes instead of underscores
        # @param options [Hash] Configuration options
        # @option options [String, Symbol] :as The method name prefix for accessing the builder
        #   Defaults to the identifier with underscores (e.g., "dropdown" → "dropdown_controller")
        # @option options [Boolean] :register (true) Whether to register this controller by default
        # @option options [Symbol, Proc] :if Conditional: only register if this returns true
        # @option options [Symbol, Proc] :unless Conditional: only register if this returns false
        # @param block [Proc, nil] Optional block to configure the builder
        #
        # @example Simple initialization
        #   controller = Poetry::Core::Stimulus::Controller.new(
        #     :dropdown,
        #     { values: { open: false } },
        #     nil
        #   )
        #
        # @example With conditional registration
        #   controller = Poetry::Core::Stimulus::Controller.new(
        #     :dismissable,
        #     { if: :dismissable?, as: :close_controller },
        #     ->(builder) { builder.with_value(:auto_close, true) }
        #   )
        def initialize(identifier, options, block)
          @identifier = Poetry::Core::Stimulus::Builder.format_identifier(identifier)
          @options = options.extract!(:as, :register, :if, :unless)
          @options[:as] ||= @identifier.tr("-", "_")
          @controller_options = options
          @block = block
        end

        # Returns the method name that will be defined on the component to access
        # this controller's builder.
        #
        # @return [String] The method name (e.g., "dropdown_controller")
        #
        # @example
        #   controller = Poetry::Core::Stimulus::Controller.new(:my_dropdown, { as: :menu }, nil)
        #   controller.method_name # => "menu_controller"
        def method_name
          "#{options[:as]}_controller"
        end

        # Checks if a configuration block was provided.
        #
        # @return [Boolean] true if a block was provided, false otherwise
        #
        # @example
        #   controller = Poetry::Core::Stimulus::Controller.new(:dropdown, {}, ->(b) { b.with_value(:x, 1) })
        #   controller.block? # => true
        #
        #   controller = Poetry::Core::Stimulus::Controller.new(:dropdown, {}, nil)
        #   controller.block? # => false
        def block?
          !!block
        end

        # Determines if this controller should be registered for the given component.
        #
        # Registration is controlled by:
        # 1. The :register option (defaults to true)
        # 2. The :if condition (must return true if present)
        # 3. The :unless condition (must return false if present)
        #
        # Conditions can be either:
        # - A symbol representing a method name on the component
        # - A Proc that will be executed in the component's context
        #
        # @param component [Object] The component instance to check conditions against
        # @return [Boolean] true if the controller should be registered, false otherwise
        #
        # @example Always register
        #   controller.register?(component) # => true (default)
        #
        # @example With :if condition using method name
        #   controller = Poetry::Core::Stimulus::Controller.new(:dismissable, { if: :dismissable? }, nil)
        #   controller.register?(component) # => true if component.dismissable? returns true
        #
        # @example With :unless condition using Proc
        #   controller = Poetry::Core::Stimulus::Controller.new(
        #     :dropdown,
        #     { unless: ->(comp) { comp.disabled? } },
        #     nil
        #   )
        #   controller.register?(component) # => false if component.disabled? returns true
        #
        # @example With register: false
        #   controller = Poetry::Core::Stimulus::Controller.new(:dropdown, { register: false }, nil)
        #   controller.register?(component) # => false
        def register?(component)
          return false unless options.fetch(:register, true)

          if_value = options[:if] ? execute_or_call(options[:if], component) : true
          unless_value = options[:unless] ? execute_or_call(options[:unless], component) : false

          if_value && !unless_value
        end

        private

        # Executes a condition value in the context of a component.
        #
        # @param value [Symbol, Proc] The condition to evaluate
        # @param component [Object] The component instance
        # @return [Object] The result of the evaluation
        #
        # @api private
        def execute_or_call(value, component)
          if value.is_a? Proc
            component.instance_exec(&value)
          else
            component.send(value)
          end
        end
      end
    end
  end
end
