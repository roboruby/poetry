# frozen_string_literal: true

module Poetry
  module Core
    # The concerns composed into {Poetry::Core::Component}: styles, options,
    # slots, Stimulus wiring, introspection, and part declarations.
    module Concerns
      # The Styles concern provides a powerful DSL for defining style attributes in components.
      # It extends the basic attribute functionality with support for variants, proc defaults,
      # and tracking of which attributes have been explicitly set vs using defaults.
      #
      # The registration, tracking, and hierarchy machinery lives in
      # DeclaredAttributes (shared with Options); this concern owns the
      # style-specific surface: variants, inclusion validation, and CSS
      # emission.
      #
      # @example Basic usage with variants
      #   class MyComponent < Poetry::Core::Component
      #     style :color, default: :primary, variants: [:primary, :secondary, :success]
      #     style :size, default: :md, variants: [:sm, :md, :lg]
      #   end
      #
      # @example Proc defaults that reference other attributes
      #   class Badge::Component < Poetry::Core::Component
      #     style :color, default: :gray, variants: [...colors]
      #     style :dot_color, default: -> { color }, variants: [...colors]
      #   end
      #
      #   badge = Badge::Component.new(color: :red)
      #   badge.dot_color  # => :red (inherits from color)
      #   badge.color = :blue
      #   badge.dot_color  # => :blue (still follows color)
      #
      #   badge2 = Badge::Component.new(color: :red, dot_color: :green)
      #   badge2.color = :blue
      #   badge2.dot_color  # => :green (explicitly set, doesn't follow color)
      #
      # @example Required attributes
      #   class MyComponent < Poetry::Core::Component
      #     style :type, required: true, variants: [:button, :link]
      #   end
      #
      # @example Boolean styles
      #   class MyComponent < Poetry::Core::Component
      #     style :outlined, variants: :boolean, default: false
      #   end
      module Styles
        extend ActiveSupport::Concern
        include DeclaredAttributes

        # The naming convention joining a component to its sidecar style
        # dictionary (Dot::Component -> Dot::Style).
        STYLE_CLASS_SUFFIX = "::Style"

        included do
          class_attribute :registered_styles,
                          instance_writer: true,
                          instance_predicate: false,
                          default: nil
        end

        class_methods do
          # Defines a style attribute for the component.
          #
          # @param name [Symbol, String] the name of the style attribute
          # @param options [Hash] configuration options
          # @option options [Object, Proc] :default the default value (can be a proc for dynamic defaults)
          # @option options [Array<Symbol>, :boolean] :variants the allowed values for this attribute
          # @option options [Boolean] :required whether this attribute must be provided
          #
          # @example Static default
          #   style :color, default: :primary, variants: [:primary, :secondary]
          #
          # @example Proc default
          #   style :dot_color, default: -> { color }, variants: [:primary, :secondary]
          #
          # @example Required attribute
          #   style :type, required: true, variants: [:button, :link]
          #
          # @example Boolean attribute
          #   style :outlined, variants: :boolean, default: false
          # @return [void]
          def style(name, **options)
            register_declared_attribute(:style, name, options)

            variants, required, default_value = extract_style_options(options)
            type = determine_attribute_type(variants)

            attribute(name, type, **options)
            add_style_validations(name, type, variants, required)
            setup_declared_tracking(:style, name, default_value)
            define_variants_getter(name, variants)
          end

          # Returns all style attributes that have default values (static or proc).
          #
          # @return [Array<Symbol>] sorted array of attribute names with defaults
          def style_attributes_with_defaults
            declared_attributes_with_defaults(:style)
          end

          # Returns style attributes that have static (non-proc) default values.
          #
          # @return [Array<Symbol>] sorted array of attribute names with static defaults
          def style_attributes_with_static_defaults
            declared_attributes_with_static_defaults(:style)
          end

          # Returns style attributes that have proc default values.
          # Proc defaults allow dynamic defaults that can reference other attributes.
          #
          # @return [Array<Symbol>] sorted array of attribute names with proc defaults
          def style_attributes_with_proc_defaults
            declared_attributes_with_proc_defaults(:style)
          end

          # Returns all style attributes defined on this component and its ancestors.
          #
          # @return [Array<Symbol>] sorted array of all style attribute names
          def style_attributes
            declared_attributes(:style)
          end

          # The doc: strings declared on this component's styles,
          # hierarchy-wide (nearest declaration wins).
          #
          # @return [Hash{Symbol => String}]
          def style_docs
            declared_docs(:style)
          end

          # Checks if the given name is a defined style attribute.
          #
          # @param name [Symbol, String] the attribute name to check
          # @return [Boolean] true if the attribute is a style attribute
          def has_style_attribute?(name)
            style_attributes.include?(name.to_sym)
          end

          # Automatically determines the corresponding Style class for this component.
          # Example: Poetry::Core::Dot::Component -> Poetry::Core::Dot::Style
          #
          # @return [Class, nil] the style class if it exists, nil otherwise
          def style_class
            style_class_name = component_module + STYLE_CLASS_SUFFIX
            style_class_name.constantize
          rescue NameError => e
            log_style_class_not_found(style_class_name, e) if defined?(Rails)
            nil
          end

          private

          # Extracts and processes style-specific options from the options hash.
          #
          # @param options [Hash] the original options hash
          # @return [Array<(Object, Boolean, Object)>] variants, required, and default_value
          def extract_style_options(options)
            variants = options.delete(:variants)
            required, default_value = extract_declared_defaults(options)

            [variants, required, default_value]
          end

          # Determines the attribute type based on the variants option.
          #
          # @param variants [Object] the variants option value
          # @return [Symbol] :boolean or :symbol
          def determine_attribute_type(variants)
            variants == :boolean ? :boolean : :symbol
          end

          # Adds validations for the style attribute.
          #
          # @param name [Symbol] the attribute name
          # @param type [Symbol] the attribute type
          # @param variants [Object] the allowed variants
          # @param required [Boolean] whether the attribute is required
          def add_style_validations(name, type, variants, required)
            if type == :boolean
              validates name, inclusion: { in: [true, false] }
            elsif variants
              validates name, inclusion: { in: variants }
            end
            validates name, presence: true if required
          end

          # Defines a singleton method to access the variants for this attribute.
          #
          # @param name [Symbol] the attribute name
          # @param variants [Object] the variants value
          def define_variants_getter(name, variants)
            define_singleton_method("#{name}_variants") { variants }
          end

          # Logs when a style class cannot be found.
          #
          # @param style_class_name [String] the name of the style class that was not found
          # @param error [NameError] the error that was raised
          def log_style_class_not_found(style_class_name, error)
            Rails.logger.debug { "Style class not found: #{style_class_name} (#{error.message})" }
          end
        end

        # Checks if the given attribute is a style attribute.
        #
        # @param name [Symbol, String] the attribute name to check
        # @return [Boolean] true if the attribute is a style attribute
        def style_attribute?(name)
          self.class.has_style_attribute?(name.to_sym)
        end

        # Returns all style attributes defined on this component's class.
        #
        # @return [Array<Symbol>] sorted array of all style attribute names
        def style_attributes
          self.class.style_attributes
        end

        # Returns only the style attributes that have been explicitly set (not using defaults).
        #
        # @return [Array<Symbol>] sorted array of initialized attribute names
        def initialized_style_attributes
          initialized_declared_attributes(registered_styles)
        end

        # Checks if a style attribute has been explicitly initialized.
        #
        # @param name [Symbol, String] the attribute name to check
        # @return [Boolean] true if the attribute was explicitly set
        def style_attribute_initialized?(name)
          declared_attribute_registered?(registered_styles, name)
        end

        # Returns all style attributes with their initialization status.
        #
        # @return [Hash{Symbol => Boolean}] map of attribute names to initialized status
        def style_attributes_status
          style_attributes.to_h do |attr|
            [attr, style_attribute_initialized?(attr)]
          end
        end

        # Returns a hash of all style attributes with their current values.
        #
        # @return [Hash{Symbol => Object}] map of attribute names to their values
        def styles
          style_attributes.to_h do |attr|
            [attr, send(attr)]
          end
        end

        # Returns the style class for this component.
        #
        # @return [Class, nil] the style class if it exists
        def styler
          self.class.style_class
        end

        # Generates CSS classes based on style attributes and additional options.
        #
        # The emission is governed by `css_mode`: `:tailwind` (default)
        # resolves the style values to utility classes through the sidecar
        # Style dictionary; `:bem` emits the stable BEM token IR instead, for
        # hosts that bring their own CSS (styled against the generated
        # reference stylesheet). Override per call with `css_mode:`, or
        # globally via `Poetry::Core::Config.current.css_mode`.
        #
        # @param element [Symbol, nil] a named element (BEM `block__element`)
        # @param options [Hash] additional style options to merge
        # @yield optional block passed to the style class
        # @return [String, nil] the generated CSS classes; nil in :tailwind
        #   mode for a component without a sidecar Style class
        # @raise [Poetry::Core::Error] for a css_mode other than :tailwind
        #   or :bem
        def css(element = nil, **options, &)
          mode = options.delete(:css_mode) || Poetry::Core::Config.current.css_mode

          case mode
          when :tailwind
            # A component with no sidecar Style class has no dictionary -
            # it renders unstyled (caught dogfooding poetry-ui's Icon).
            return nil unless styler

            style_attributes = styles.merge(options)
            styler.css(element, **style_attributes, &)
          when :bem
            extra = options.delete(:class)
            [bem(element, **options), extra].compact.join(" ")
          else
            raise Poetry::Core::Error, "unknown css_mode #{mode.inspect} (expected :tailwind or :bem)"
          end
        end

        # The component's BEM block name - the stable, framework-agnostic
        # class contract of the token IR ("poetry/core/dot" -> "poetry-core-dot").
        #
        # @return [String]
        def bem_block
          self.class.component_path.tr("/", "-")
        end

        # The BEM token IR for this component (the pipeline's Step 2): the
        # block class plus one modifier class per style value - symbols as
        # `block--attr-value`, booleans as presence modifiers (`block--attr`).
        # A named element returns `block__element`.
        #
        # @param element [Symbol, nil] a named element
        # @param overrides [Hash] style overrides merged over the resolved values
        # @return [String] space-separated BEM classes
        def bem(element = nil, **overrides)
          return "#{bem_block}__#{element}" if element

          styles.merge(overrides).each_with_object([bem_block]) do |(attr, value), tokens|
            next if value.nil? || value == false

            tokens << (value == true ? "#{bem_block}--#{attr}" : "#{bem_block}--#{attr}-#{value}")
          end.join(" ")
        end
      end
    end
  end
end
