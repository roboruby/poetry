# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The Options concern provides a DSL for defining typed attributes in components.
      # It extends the basic attribute functionality with support for ActiveModel types,
      # proc defaults, and tracking of which attributes have been explicitly set vs using defaults.
      #
      # Unlike Styles, Options:
      # - Do not have variants
      # - Do not generate CSS
      # - Support all ActiveModel types (string, integer, boolean, float, etc.)
      #
      # @example Basic usage with types
      #   class MyComponent < Poetry::Core::Component
      #     option :title, :string, default: "Untitled"
      #     option :count, :integer, default: 0
      #     option :enabled, :boolean, default: true
      #   end
      #
      # @example Proc defaults that reference other attributes
      #   class Card::Component < Poetry::Core::Component
      #     option :title, :string, default: "Card"
      #     option :aria_label, :string, default: -> { title }
      #   end
      #
      #   card = Card::Component.new(title: "My Card")
      #   card.aria_label  # => "My Card" (inherited from title)
      #   card.title = "Updated"
      #   card.aria_label  # => "Updated" (still follows title)
      #
      #   card2 = Card::Component.new(title: "Card", aria_label: "Custom Label")
      #   card2.title = "Updated"
      #   card2.aria_label  # => "Custom Label" (explicitly set, doesn't follow title)
      #
      # @example Required attributes
      #   class MyComponent < Poetry::Core::Component
      #     option :id, :string, required: true
      #   end
      #
      # @example Various types
      #   class MyComponent < Poetry::Core::Component
      #     option :price, :decimal
      #     option :score, :float
      #     option :created_at, :datetime
      #   end
      module Options
        extend ActiveSupport::Concern

        BASE_COMPONENT_CLASS = Poetry::Core::Component

        included do
          class_attribute :registered_options,
                          instance_writer: true,
                          instance_predicate: false,
                          default: nil
        end

        class_methods do
          # Defines an option attribute for the component.
          #
          # @param name [Symbol, String] the name of the option attribute
          # @param type [Symbol] the ActiveModel type (:string, :integer, :boolean, :float, :decimal, :value, etc.)
          # @param options [Hash] configuration options
          # @option options [Object, Proc] :default the default value (can be a proc for dynamic defaults)
          # @option options [Boolean] :required whether this attribute must be provided
          #
          # @example Static default
          #   option :title, :string, default: "Untitled"
          #
          # @example Proc default
          #   option :aria_label, :string, default: -> { title }
          #
          # @example Required attribute
          #   option :id, :string, required: true
          #
          # @example Boolean attribute
          #   option :enabled, :boolean, default: false
          #
          # @example Value format (machine-checkable value contract)
          #   option :name, :symbol, required: true, format: :"icon-name"
          def option(name, type, **options)
            register_option_attribute(name, options)

            required, default_value = extract_option_options(options)
            register_option_format(name, options.delete(:format))

            define_option_attribute(name, type, options)
            add_option_validations(name, type, required)
            setup_option_tracking(name, default_value)
            define_type_getter(name, type)
          end

          # Returns all option attributes that have default values (static or proc).
          #
          # @return [Array<Symbol>] sorted array of attribute names with defaults
          def option_attributes_with_defaults
            collect_option_attributes_from_hierarchy(:@_option_attributes_with_defaults)
          end

          # Returns option attributes that have static (non-proc) default values.
          #
          # @return [Array<Symbol>] sorted array of attribute names with static defaults
          def option_attributes_with_static_defaults
            ivar = :@_option_attributes_with_defaults
            collect_option_attributes_from_hierarchy(ivar) do |attributes_set, defaults, klass|
              next unless defaults

              proc_defaults = klass.instance_variable_get(:@_option_proc_defaults)
              defaults.each do |attr|
                attributes_set << attr unless proc_defaults&.key?(attr)
              end
            end
          end

          # Returns option attributes that have proc default values.
          # Proc defaults allow dynamic defaults that can reference other attributes.
          #
          # @return [Array<Symbol>] sorted array of attribute names with proc defaults
          def option_attributes_with_proc_defaults
            collect_option_attributes_from_hierarchy(:@_option_proc_defaults) do |attributes_set, proc_defaults, _klass|
              attributes_set.merge(proc_defaults.keys) if proc_defaults
            end
          end

          # Returns all option attributes defined on this component and its ancestors.
          #
          # @return [Array<Symbol>] sorted array of all option attribute names
          def option_attributes
            collect_option_attributes_from_hierarchy(:@_option_attributes)
          end

          # Checks if the given name is a defined option attribute.
          #
          # @param name [Symbol, String] the attribute name to check
          # @return [Boolean] true if the attribute is an option attribute
          def has_option_attribute?(name)
            option_attributes.include?(name.to_sym)
          end

          # Returns the type for a given option attribute.
          #
          # @param name [Symbol, String] the attribute name
          # @return [Symbol, nil] the type of the attribute
          def option_type(name)
            types = collect_option_types_from_hierarchy
            types[name.to_sym]
          end

          # Returns the declared value format for a given option attribute
          # (e.g. :"icon-name") - the machine-checkable value contract the
          # registry and poetry check read. Nil when the option is free-form.
          #
          # @param name [Symbol, String] the attribute name
          # @return [Symbol, nil] the declared format
          def option_format(name)
            formats = {}
            klass = self

            while klass&.respond_to?(:instance_variable_get)
              klass_formats = klass.instance_variable_get(:@_option_formats)
              formats = klass_formats.merge(formats) if klass_formats

              klass = klass.superclass
              break if klass == BASE_COMPONENT_CLASS || !klass.ancestors.include?(BASE_COMPONENT_CLASS)
            end

            formats[name.to_sym]
          end

          private

          # Collects option types from the class hierarchy.
          #
          # @return [Hash{Symbol => Symbol}] map of attribute names to types
          def collect_option_types_from_hierarchy
            types = {}
            klass = self

            while klass&.respond_to?(:instance_variable_get)
              klass_types = klass.instance_variable_get(:@_option_types)
              types.merge!(klass_types) if klass_types

              klass = klass.superclass
              break if klass == BASE_COMPONENT_CLASS || !klass.ancestors.include?(BASE_COMPONENT_CLASS)
            end

            types
          end

          # Registers an option attribute and tracks it in the appropriate collections.
          #
          # @param name [Symbol, String] the attribute name
          # @param options [Hash] the attribute options
          def register_option_attribute(name, options)
            (@_option_attributes ||= Set.new) << name.to_sym

            (@_option_attributes_with_defaults ||= Set.new) << name.to_sym if options.key?(:default)

            return unless options[:default].is_a?(Proc)

            (@_option_proc_defaults ||= {})[name.to_sym] = options[:default]
          end

          # Records a declared value format so option_format can surface it
          # (hierarchy-walked like types, so subclasses inherit it).
          #
          # @param name [Symbol, String] the attribute name
          # @param format [Symbol, nil] the declared format, if any
          def register_option_format(name, format)
            return unless format

            (@_option_formats ||= {})[name.to_sym] = format.to_sym
          end

          # Extracts and processes option-specific options from the options hash.
          #
          # @param options [Hash] the original options hash
          # @return [Array<(Boolean, Object)>] required and default_value
          def extract_option_options(options)
            default_value = options[:default]
            options.delete(:default) if default_value.is_a?(Proc)

            required = options.delete(:required) || false

            [required, default_value]
          end

          # Defines the attribute using the base attribute method.
          #
          # @param name [Symbol] the attribute name
          # @param type [Symbol] the attribute type
          # @param options [Hash] remaining options to pass to attribute
          def define_option_attribute(name, type, options)
            attribute(name, type, **options)
          end

          # Adds validations for the option attribute.
          #
          # @param name [Symbol] the attribute name
          # @param type [Symbol] the attribute type
          # @param required [Boolean] whether the attribute is required
          def add_option_validations(name, _type, required)
            # Type validation is automatic via ActiveModel::Type
            validates name, presence: true if required
          end

          # Sets up tracking for option attribute initialization.
          #
          # @param name [Symbol] the attribute name
          # @param default_value [Object] the default value (may be a Proc)
          def setup_option_tracking(name, default_value)
            override_option_setter_for_tracking(name)
            override_option_getter_for_proc_default(name, default_value) if default_value.is_a?(Proc)
          end

          # Overrides the setter to track when the attribute is initialized.
          #
          # @param name [Symbol] the attribute name
          def override_option_setter_for_tracking(name)
            original_setter = instance_method("#{name}=")
            define_method("#{name}=") do |value|
              self.registered_options ||= Set.new
              registered_options << name.to_sym
              original_setter.bind_call(self, value)
            end
          end

          # Overrides the getter to handle proc defaults dynamically.
          #
          # @param name [Symbol] the attribute name
          # @param default_value [Proc] the proc that provides the default value
          def override_option_getter_for_proc_default(name, default_value)
            original_getter = instance_method(name)

            define_method(name) do
              if option_attribute_initialized?(name)
                original_getter.bind_call(self)
              else
                value = instance_exec(&default_value)
                @attributes.write_from_user(name.to_s, value)
                value
              end
            end
          end

          # Defines a singleton method to access the type for this attribute.
          #
          # @param name [Symbol] the attribute name
          # @param type [Symbol] the type value
          def define_type_getter(name, type)
            (@_option_types ||= {})[name.to_sym] = type
            define_singleton_method("#{name}_type") { type }
          end

          # Collects attributes from the class hierarchy.
          # This method walks up the inheritance chain and collects instance variables.
          #
          # @param ivar_name [Symbol] the instance variable name to collect
          # @yield [attributes_set, values, klass] optional block for custom collection logic
          # @return [Array<Symbol>] sorted array of collected attributes
          def collect_option_attributes_from_hierarchy(ivar_name)
            attributes_set = Set.new
            klass = self

            while klass&.respond_to?(:instance_variable_get)
              values = klass.instance_variable_get(ivar_name)

              if block_given?
                yield(attributes_set, values, klass)
              elsif values
                attributes_set.merge(values)
              end

              klass = klass.superclass
              break if klass == BASE_COMPONENT_CLASS || !klass.ancestors.include?(BASE_COMPONENT_CLASS)
            end

            attributes_set.to_a.sort
          end
        end

        # Checks if the given attribute is an option attribute.
        #
        # @param name [Symbol, String] the attribute name to check
        # @return [Boolean] true if the attribute is an option attribute
        def option_attribute?(name)
          self.class.has_option_attribute?(name.to_sym)
        end

        # Returns all option attributes defined on this component's class.
        #
        # @return [Array<Symbol>] sorted array of all option attribute names
        def option_attributes
          self.class.option_attributes
        end

        # Returns only the option attributes that have been explicitly set (not using defaults).
        #
        # @return [Array<Symbol>] sorted array of initialized attribute names
        def initialized_option_attributes
          return [] if registered_options.nil?

          registered_options.to_a.sort
        end

        # Checks if an option attribute has been explicitly initialized.
        #
        # @param name [Symbol, String] the attribute name to check
        # @return [Boolean] true if the attribute was explicitly set
        def option_attribute_initialized?(name)
          return false if registered_options.nil?

          registered_options.include?(name.to_sym)
        end

        # Returns all option attributes with their initialization status.
        #
        # @return [Hash{Symbol => Boolean}] map of attribute names to initialized status
        def option_attributes_status
          option_attributes.to_h do |attr|
            [attr, option_attribute_initialized?(attr)]
          end
        end

        # Returns a hash of all option attributes with their current values.
        #
        # @return [Hash{Symbol => Object}] map of attribute names to their values
        def options
          option_attributes.to_h do |attr|
            [attr, send(attr)]
          end
        end
      end
    end
  end
end
