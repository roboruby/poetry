# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The declared-attribute engine shared by the Styles and Options DSLs.
      # Each DSL is one "kind" of declared attribute: registration lands in
      # per-kind class-level collections (@_<kind>_attributes,
      # @_<kind>_attributes_with_defaults, @_<kind>_proc_defaults), explicit
      # initialization is tracked per instance through the registered_<kind>s
      # class_attribute the owning concern declares, and hierarchy-wide
      # queries walk the ancestry up to the base component class.
      # Kind-specific surface - variants and CSS emission for styles,
      # ActiveModel types and value formats for options - stays in the
      # owning concern.
      module DeclaredAttributes
        extend ActiveSupport::Concern

        BASE_COMPONENT_CLASS = Poetry::Core::Component

        class_methods do
          private

          # Registers a declared attribute in the per-kind class-level
          # collections. Runs before any option extraction so the presence
          # of :default (static or proc) is still observable.
          #
          # @param kind [Symbol] :style or :option
          # @param name [Symbol, String] the attribute name
          # @param options [Hash] the attribute options
          def register_declared_attribute(kind, name, options)
            declared_ivar_set(:"@_#{kind}_attributes") << name.to_sym

            declared_ivar_set(:"@_#{kind}_attributes_with_defaults") << name.to_sym if options.key?(:default)

            return unless options[:default].is_a?(Proc)

            declared_ivar_hash(:"@_#{kind}_proc_defaults")[name.to_sym] = options[:default]
          end

          # Extracts the shared :default/:required options. A proc default
          # is deleted so ActiveModel never installs it (the getter override
          # evaluates it lazily against the instance); a static default
          # stays in the hash for `attribute` to install.
          #
          # @param options [Hash] the original options hash
          # @return [Array<(Boolean, Object)>] required and default_value
          def extract_declared_defaults(options)
            default_value = options[:default]
            options.delete(:default) if default_value.is_a?(Proc)

            required = options.delete(:required) || false

            [required, default_value]
          end

          # Sets up per-instance initialization tracking: every declared
          # attribute records explicit writes; a proc default additionally
          # resolves through the tracked state on read.
          #
          # @param kind [Symbol] :style or :option
          # @param name [Symbol] the attribute name
          # @param default_value [Object] the default value (may be a Proc)
          def setup_declared_tracking(kind, name, default_value)
            override_declared_setter_for_tracking(kind, name)
            override_declared_getter_for_proc_default(kind, name, default_value) if default_value.is_a?(Proc)
          end

          # Overrides the setter to record the attribute in the kind's
          # registered set.
          #
          # @param kind [Symbol] :style or :option
          # @param name [Symbol] the attribute name
          def override_declared_setter_for_tracking(kind, name)
            original_setter = instance_method("#{name}=")
            registry_reader = :"registered_#{kind}s"
            registry_writer = :"registered_#{kind}s="

            define_method("#{name}=") do |value|
              public_send(registry_writer, Set.new) if public_send(registry_reader).nil?
              public_send(registry_reader) << name.to_sym
              original_setter.bind_call(self, value)
            end
          end

          # Overrides the getter so an unset attribute evaluates its proc
          # default against the instance (other attributes are readable),
          # surfacing the value in the attributes hash without marking the
          # attribute initialized - reads keep following the proc until an
          # explicit write.
          #
          # @param kind [Symbol] :style or :option
          # @param name [Symbol] the attribute name
          # @param default_value [Proc] the proc that provides the default value
          def override_declared_getter_for_proc_default(kind, name, default_value)
            original_getter = instance_method(name)
            initialized_predicate = :"#{kind}_attribute_initialized?"

            define_method(name) do
              if public_send(initialized_predicate, name)
                original_getter.bind_call(self)
              else
                value = instance_exec(&default_value)
                @attributes.write_from_user(name.to_s, value)
                value
              end
            end
          end

          # All declared attributes of a kind across the hierarchy.
          #
          # @param kind [Symbol] :style or :option
          # @return [Array<Symbol>] sorted array of attribute names
          def declared_attributes(kind)
            collect_declared_set(:"@_#{kind}_attributes")
          end

          # Declared attributes of a kind with any default (static or proc).
          #
          # @param kind [Symbol] :style or :option
          # @return [Array<Symbol>] sorted array of attribute names
          def declared_attributes_with_defaults(kind)
            collect_declared_set(:"@_#{kind}_attributes_with_defaults")
          end

          # Declared attributes of a kind with a static (non-proc) default.
          #
          # @param kind [Symbol] :style or :option
          # @return [Array<Symbol>] sorted array of attribute names
          def declared_attributes_with_static_defaults(kind)
            proc_defaults_ivar = :"@_#{kind}_proc_defaults"

            collect_declared_set(:"@_#{kind}_attributes_with_defaults") do |attributes_set, defaults, klass|
              next unless defaults

              proc_defaults = klass.instance_variable_get(proc_defaults_ivar)
              defaults.each do |attr|
                attributes_set << attr unless proc_defaults&.key?(attr)
              end
            end
          end

          # Declared attributes of a kind with a proc default.
          #
          # @param kind [Symbol] :style or :option
          # @return [Array<Symbol>] sorted array of attribute names
          def declared_attributes_with_proc_defaults(kind)
            collect_declared_set(:"@_#{kind}_proc_defaults") do |attributes_set, proc_defaults, _klass|
              attributes_set.merge(proc_defaults.keys) if proc_defaults
            end
          end

          # Collects a Set-valued class-level collection across the
          # hierarchy.
          #
          # @param ivar_name [Symbol] the instance variable name to collect
          # @yield [attributes_set, values, klass] optional block for custom collection logic
          # @return [Array<Symbol>] sorted array of collected attributes
          def collect_declared_set(ivar_name)
            attributes_set = Set.new

            declared_hierarchy do |klass|
              values = klass.instance_variable_get(ivar_name)

              if block_given?
                yield(attributes_set, values, klass)
              elsif values
                attributes_set.merge(values)
              end
            end

            attributes_set.to_a.sort
          end

          # Collects a Hash-valued class-level collection across the
          # hierarchy; the nearest declaration wins on key conflicts.
          #
          # @param ivar_name [Symbol] the instance variable name to collect
          # @return [Hash{Symbol => Object}]
          def collect_declared_map(ivar_name)
            map = {}

            declared_hierarchy do |klass|
              klass_map = klass.instance_variable_get(ivar_name)
              map = klass_map.merge(map) if klass_map
            end

            map
          end

          # Walks the ancestry from this class toward the base component
          # class, yielding each class that can carry declarations. The base
          # class itself is never yielded.
          def declared_hierarchy
            klass = self

            while klass&.respond_to?(:instance_variable_get)
              yield klass

              klass = klass.superclass
              break if klass == BASE_COMPONENT_CLASS || !klass.ancestors.include?(BASE_COMPONENT_CLASS)
            end
          end

          # The class-level Set for an ivar, created on first use.
          #
          # @param ivar_name [Symbol]
          # @return [Set]
          def declared_ivar_set(ivar_name)
            instance_variable_get(ivar_name) || instance_variable_set(ivar_name, Set.new)
          end

          # The class-level Hash for an ivar, created on first use.
          #
          # @param ivar_name [Symbol]
          # @return [Hash]
          def declared_ivar_hash(ivar_name)
            instance_variable_get(ivar_name) || instance_variable_set(ivar_name, {})
          end
        end

        # The cop cannot see across the class_methods block boundary: this
        # modifier governs the module's instance methods, not the block's.
        private # rubocop:disable Lint/UselessAccessModifier

        # The initialized-attribute list behind a kind's registered set.
        #
        # @param registry [Set, nil] the per-instance registered set
        # @return [Array<Symbol>] sorted array of initialized attribute names
        def initialized_declared_attributes(registry)
          return [] if registry.nil?

          registry.to_a.sort
        end

        # Whether an attribute is recorded in a kind's registered set.
        #
        # @param registry [Set, nil] the per-instance registered set
        # @param name [Symbol, String] the attribute name
        # @return [Boolean] true if the attribute was explicitly set
        def declared_attribute_registered?(registry, name)
          return false if registry.nil?

          registry.include?(name.to_sym)
        end
      end
    end
  end
end
