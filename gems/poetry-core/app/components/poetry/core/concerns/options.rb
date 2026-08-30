# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The Options concern provides a DSL for defining typed attributes in components.
      # It extends the basic attribute functionality with support for ActiveModel types,
      # proc defaults, and tracking of which attributes have been explicitly set vs using defaults.
      #
      # The registration, tracking, and hierarchy machinery lives in
      # DeclaredAttributes (shared with Styles); this concern owns the
      # option-specific surface: ActiveModel types and value formats.
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
        include DeclaredAttributes

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
          # @return [void]
          def option(name, type, **options)
            register_declared_attribute(:option, name, options)

            required, default_value = extract_declared_defaults(options)
            register_option_format(name, options.delete(:format))

            attribute(name, type, **options)
            add_option_validations(name, type, required)
            setup_declared_tracking(:option, name, default_value)
            define_type_getter(name, type)
          end

          # Returns all option attributes that have default values (static or proc).
          #
          # @return [Array<Symbol>] sorted array of attribute names with defaults
          def option_attributes_with_defaults
            declared_attributes_with_defaults(:option)
          end

          # Returns option attributes that have static (non-proc) default values.
          #
          # @return [Array<Symbol>] sorted array of attribute names with static defaults
          def option_attributes_with_static_defaults
            declared_attributes_with_static_defaults(:option)
          end

          # Returns option attributes that have proc default values.
          # Proc defaults allow dynamic defaults that can reference other attributes.
          #
          # @return [Array<Symbol>] sorted array of attribute names with proc defaults
          def option_attributes_with_proc_defaults
            declared_attributes_with_proc_defaults(:option)
          end

          # Returns all option attributes defined on this component and its ancestors.
          #
          # @return [Array<Symbol>] sorted array of all option attribute names
          def option_attributes
            declared_attributes(:option)
          end

          # The doc: strings declared on this component's options,
          # hierarchy-wide (nearest declaration wins).
          #
          # @return [Hash{Symbol => String}]
          def option_docs
            declared_docs(:option)
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
            collect_declared_map(:@_option_formats)[name.to_sym]
          end

          private

          # Collects option types from the class hierarchy. An ancestor's
          # declaration wins on redeclaration (formats resolve the other
          # way, nearest wins).
          #
          # @return [Hash{Symbol => Symbol}] map of attribute names to types
          def collect_option_types_from_hierarchy
            types = {}

            declared_hierarchy do |klass|
              klass_types = klass.instance_variable_get(:@_option_types)
              types.merge!(klass_types) if klass_types
            end

            types
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

          # Adds validations for the option attribute.
          #
          # @param name [Symbol] the attribute name
          # @param _type [Symbol] the attribute type (unused; kept for signature parity)
          # @param required [Boolean] whether the attribute is required
          def add_option_validations(name, _type, required)
            # Type validation is automatic via ActiveModel::Type
            validates name, presence: true if required
          end

          # Defines a singleton method to access the type for this attribute.
          #
          # @param name [Symbol] the attribute name
          # @param type [Symbol] the type value
          def define_type_getter(name, type)
            (@_option_types ||= {})[name.to_sym] = type
            define_singleton_method("#{name}_type") { type }
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
          initialized_declared_attributes(registered_options)
        end

        # Checks if an option attribute has been explicitly initialized.
        #
        # @param name [Symbol, String] the attribute name to check
        # @return [Boolean] true if the attribute was explicitly set
        def option_attribute_initialized?(name)
          declared_attribute_registered?(registered_options, name)
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
