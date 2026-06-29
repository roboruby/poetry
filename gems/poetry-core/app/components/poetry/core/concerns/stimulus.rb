# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # Provides declarative Stimulus controller integration for ViewComponents.
      #
      # This concern enables components to register Stimulus controllers using a simple
      # DSL. Controllers can be conditionally registered based on component state and
      # configured using a block-based API. The concern manages the lifecycle of
      # Stimulus controllers, automatically registering them before rendering.
      #
      # @example Basic usage
      #   class DropdownComponent < Poetry::Core::Component
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     stimulated_with :dropdown do |controller|
      #       controller.with_value(:open, false)
      #       controller.with_action(:toggle, on: :click)
      #     end
      #   end
      #
      # @example Conditional registration
      #   class AlertComponent < Poetry::Core::Component
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     attribute :dismissable, :boolean, default: false
      #
      #     stimulated_with :dismissable, if: :dismissable? do |controller|
      #       controller.with_action(:dismiss, on: :click)
      #     end
      #
      #     def dismissable?
      #       !!dismissable
      #     end
      #   end
      #
      # @example Custom method name
      #   class MenuComponent < Poetry::Core::Component
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     stimulated_with :dropdown, as: :menu do |controller|
      #       controller.with_value(:position, "bottom")
      #     end
      #
      #     # Access via menu_controller method
      #     def before_render
      #       menu_controller.with_value(:items, @items.count)
      #       super
      #     end
      #   end
      #
      # @example Namespaced controllers
      #   class TooltipComponent < Poetry::Core::Component
      #     include Poetry::Core::Concerns::Stimulus
      #
      #     stimulated_with [:poetry, :tooltip] do |controller|
      #       controller.with_value(:text, "Hello")
      #       controller.with_value(:position, "top")
      #     end
      #   end
      #
      # @see Poetry::Core::Stimulus::Controller
      # @see Poetry::Core::Stimulus::Manager
      # @see Poetry::Core::Stimulus::Builder
      module Stimulus
        extend ActiveSupport::Concern

        included do
          # @!attribute [r] stimulus_controllers
          #   @return [ActiveSupport::HashWithIndifferentAccess] Hash of registered controller configurations
          class_attribute :stimulus_controllers,
                          instance_writer: false,
                          instance_predicate: false

          self.stimulus_controllers = ActiveSupport::HashWithIndifferentAccess.new
        end

        class_methods do
          # Declares a Stimulus controller for this component.
          #
          # Creates a controller configuration that will be automatically registered
          # during rendering. Also defines a method on the component to access the
          # controller's builder for additional configuration.
          #
          # @param identifier [String, Symbol, Array] The Stimulus controller identifier(s)
          #   Underscores are converted to dashes. Arrays are joined with "--" for namespacing.
          # @param options [Hash] Configuration options
          # @option options [String, Symbol] :as The method name prefix for accessing the builder
          #   Defaults to the identifier with underscores (e.g., "dropdown" → "dropdown_controller")
          # @option options [Boolean] :register (true) Whether to register by default
          # @option options [Symbol, Proc] :if Condition for registration (must return true)
          # @option options [Symbol, Proc] :unless Condition for registration (must return false)
          # @option options [Hash] :values Initial Stimulus values
          # @option options [Hash] :classes Initial Stimulus classes
          # @option options [Hash] :actions Initial Stimulus actions
          # @yield [builder] Optional configuration block for the builder
          # @yieldparam builder [Poetry::Core::Stimulus::Builder] The Stimulus builder instance
          #
          # @example Simple controller
          #   stimulated_with :dropdown
          #
          # @example With initial values
          #   stimulated_with :modal, values: { open: false, size: "lg" }
          #
          # @example With configuration block
          #   stimulated_with :dropdown do |controller|
          #     controller.with_value(:open, false)
          #     controller.with_action(:toggle, on: :click)
          #   end
          #
          # @example With conditional registration
          #   stimulated_with :dismissable, if: :dismissable? do |controller|
          #     controller.with_action(:dismiss, on: :click)
          #   end
          #
          # @example With custom method name
          #   stimulated_with :dropdown, as: :menu do |controller|
          #     controller.with_value(:position, "bottom")
          #   end
          #   # Accessible via menu_controller method
          #
          # @example Namespaced controller
          #   stimulated_with [:poetry, :tooltip] do |controller|
          #     controller.with_value(:text, "Hello")
          #   end
          #
          # @return [void]
          def stimulated_with(identifier, options = {}, &block)
            stimulus_controller = Poetry::Core::Stimulus::Controller.new(identifier, options, block)
            self.stimulus_controllers =
              stimulus_controllers.merge(stimulus_controller.identifier => stimulus_controller)

            define_method stimulus_controller.method_name do
              stimulated.with(identifier)
            end
          end
        end

        # Registers Stimulus controllers before rendering the component.
        #
        # This method is automatically called by ViewComponent's rendering lifecycle.
        # It iterates through all declared controllers and registers them if they:
        # 1. Haven't been registered yet
        # 2. Meet their registration conditions (if/unless)
        # 3. Have register: true (the default)
        #
        # Configuration blocks are executed in the component's context, allowing
        # access to component state and methods.
        #
        # @return [void]
        # @api private
        def before_render
          stimulus_controllers.each_value do |controller|
            next if stimulated.registered?(controller.identifier) || !controller.register?(self)

            stimulated.register(controller.identifier, controller.controller_options).tap do |builder|
              instance_exec builder, &controller.block if controller.block
            end
          end

          super
        end

        # Returns the Stimulus manager for this component.
        #
        # The manager coordinates all Stimulus controllers registered with this component
        # and provides methods for accessing, registering, and configuring them.
        #
        # @return [Poetry::Core::Stimulus::Manager] The manager instance for this component
        #
        # @example Access the manager
        #   def some_method
        #     stimulated.register("dropdown")
        #     stimulated.with("modal").with_value(:open, true)
        #   end
        #
        # @example Check if a controller is registered
        #   def dropdown_active?
        #     stimulated.registered?("dropdown")
        #   end
        def stimulated
          @stimulated ||= Poetry::Core::Stimulus::Manager.new(@html_attributes)
        end
      end
    end
  end
end
