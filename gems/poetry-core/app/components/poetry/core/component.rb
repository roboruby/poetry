# frozen_string_literal: true

module Poetry
  module Core
    # Base component class for all Poetry components.
    #
    # This class serves as the foundation for all Poetry components, providing:
    # - ActiveModel integration for attributes, assignment, and validations
    # - Style attribute management with variants and proc defaults
    # - HTML attribute handling and merging
    # - Translation and wrapping helpers
    # - Classname merging functionality
    # - Component metadata and identification methods
    #
    # @example Basic component usage
    #   class MyComponent < Poetry::Core::Component
    #     style :color, default: :primary, variants: [:primary, :secondary]
    #     style :size, default: :md, variants: [:sm, :md, :lg]
    #   end
    #
    #   component = MyComponent.new(color: :secondary, size: :lg, class: "custom-class")
    #   component.color         # => :secondary
    #   component.size          # => :lg
    #   component.html_attributes # => { class: "... custom-class" }
    #
    # @example Component with proc defaults
    #   class Badge < Poetry::Core::Component
    #     style :color, default: :gray, variants: [:gray, :red, :blue]
    #     style :dot_color, default: -> { color }, variants: [:gray, :red, :blue]
    #   end
    #
    #   badge = Badge.new(color: :red)
    #   badge.dot_color  # => :red (inherits from color)
    #
    # @see Poetry::Core::Concerns::Styles
    # @see Poetry::Core::Concerns::Options
    class Component < ViewComponent::Base
      include ActiveModel::Attributes
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      include Poetry::Core::Contrib::TranslationHelper
      include Poetry::Core::Contrib::WrappedHelper
      include Poetry::Core::Concerns::Styles
      include Poetry::Core::Concerns::Options
      include Poetry::Core::Concerns::Stimulus
      include Poetry::Core::Concerns::Introspection
      include Poetry::Core::Concerns::Parts

      class << self
        # Returns the current Poetry::Core configuration.
        #
        # @return [Poetry::Core::Config] the current configuration instance
        def config
          Poetry::Core::Config.current
        end

        # Returns the component name in underscored path format.
        # Removes the "::Component" or "Component" suffix and converts to snake_case.
        #
        # @return [String] the component path (e.g., "poetry/core/dot")
        # @example
        #   Poetry::Core::Dot::Component.component_path # => "poetry/core/dot"
        #   Poetry::Core::Button::Component.component_path # => "poetry/core/button"
        def component_path
          name.sub(/(::Component|Component)$/, "").underscore # poetry/core/dot
        end

        # Returns the component module name without the "::Component" suffix.
        #
        # @return [String] the module name (e.g., "Poetry::Core::Dot")
        # @example
        #   Poetry::Core::Dot::Component.component_module # => "Poetry::Core::Dot"
        def component_module
          name.sub(/::Component$/, "")
        end

        # Returns the component identifier with path segments joined by double dashes.
        # Useful for CSS class names and HTML data attributes.
        #
        # @return [String] the component identifier (e.g., "poetry--core--dot")
        # @example
        #   Poetry::Core::Dot::Component.component_identifier # => "poetry--core--dot"
        #   Poetry::Core::Button::Component.component_identifier # => "poetry--core--button"
        def component_identifier
          component_path.split("/").join("--") # poetry--core--dot
        end

        # Returns the last segment of the component path as the title.
        #
        # @return [String] the component title (e.g., "dot")
        # @example
        #   Poetry::Core::Dot::Component.component_title # => "dot"
        #   Poetry::Core::Button::Component.component_title # => "button"
        def component_title
          component_path.split("/").last # dot
        end

        # Declares that this component cannot render without a content block,
        # with a hint naming what the block is (Avatar: "the initials
        # fallback"). ONE declaration feeds both enforcement layers: the
        # component raises via #ensure_content! at render, and the registry
        # emits `requires_content` so poetry check flags the omission
        # statically (the floating crash class).
        #
        # @param hint [String] what the content block is, for the error message
        def requires_content(hint)
          @required_content = hint
        end

        # The declared content-block hint, inherited like other DSL state.
        #
        # @return [String, nil]
        def required_content
          return @required_content if defined?(@required_content)

          superclass.respond_to?(:required_content) ? superclass.required_content : nil
        end
      end

      # The self-identification markup contract (M3, the golden Button's
      # convention): `data-component` on the component root maps live DOM
      # back to the component that rendered it - the hook agents, the
      # Verifier, and the browser-verification loop key on.
      #
      # @return [Hash] e.g. { "data-component" => "button" }
      def component_data_attributes
        { "data-component" => self.class.component_title }
      end

      # `data-slot` for a named part of the component's anatomy
      # (skeleton parts carry their role: icon, label, spinner, ...).
      #
      # @param part [Symbol, String] the anatomy part name
      # @return [Hash] e.g. { "data-slot" => "icon" }
      def slot_data_attributes(part)
        { "data-slot" => part.to_s }
      end

      # Enforces the class-level requires_content declaration - call from
      # before_render. The message is built from the declaration so the
      # runtime raise and the registry's static contract can never disagree.
      def ensure_content!
        return if content?

        raise ArgumentError, "#{self.class.component_module.demodulize} requires a content block " \
                             "(#{self.class.required_content})"
      end

      # Indicates whether this component instance is persisted.
      # Always returns false as components are not persisted entities.
      #
      # @return [Boolean] always returns false
      def persisted?
        false
      end

      # Initializes a new component instance with the given attributes.
      #
      # This method:
      # 1. Initializes the registered_styles set for tracking explicitly set attributes
      # 2. Marks style attributes with static defaults as initialized
      # 3. Tracks which style attributes are being explicitly initialized via parameters
      # 4. Separates component attributes from HTML attributes
      # 5. Assigns the component attributes to their respective instance variables
      #
      # @param attributes [Hash] the attributes to initialize the component with
      # @option attributes [Symbol, String] style attributes defined via the `style` DSL
      # @option attributes [Symbol, String] HTML attributes (e.g., :class, :id, :data)
      #
      # @example Initialize with style attributes
      #   component = MyComponent.new(color: :primary, size: :lg)
      #
      # @example Initialize with HTML attributes
      #   component = MyComponent.new(class: "my-class", data: { controller: "example" })
      #
      # @example Initialize with both
      #   component = MyComponent.new(color: :primary, class: "my-class")
      #
      # The base component intentionally does not chain to ViewComponent::Base#initialize:
      # it fully manages its own ActiveModel-backed attribute setup.
      def initialize(attributes = {}) # rubocop:disable Lint/MissingSuper
        # Initialize a fresh Set for this instance
        self.registered_styles = Set.new
        self.registered_options = Set.new

        # First, mark all style attributes with static defaults as initialized
        # (proc defaults should NOT be marked as initialized, so they get evaluated lazily)
        self.class.style_attributes_with_static_defaults.each do |attr|
          registered_styles << attr.to_sym
        end

        # First, mark all option attributes with static defaults as initialized
        # (proc defaults should NOT be marked as initialized, so they get evaluated lazily)
        self.class.option_attributes_with_static_defaults.each do |attr|
          registered_options << attr.to_sym
        end

        # Then track which style attributes are being explicitly initialized
        attributes.each_key do |key|
          registered_styles << key.to_sym if self.class.has_style_attribute?(key)

          # Then track which option attributes are being explicitly initialized
          registered_options << key.to_sym if self.class.has_option_attribute?(key)
        end

        @attributes = self.class._default_attributes.deep_dup
        html_attrs = attributes.with_indifferent_access.except(*attribute_names)
        @html_attributes = Poetry::Core::HTML::Attributes.new(html_attrs)

        assign_attributes attributes.with_indifferent_access.slice(*attribute_names)
      end

      # Returns all component attributes, ensuring proc defaults are evaluated.
      #
      # This method overrides ActiveModel's attributes method to trigger evaluation
      # of any proc-based default values that haven't been explicitly set.
      #
      # @return [Hash] the component's attributes with all defaults evaluated
      def attributes
        # Trigger evaluation of proc defaults that haven't been explicitly set
        # This ensures they appear in the attributes hash
        self.class.style_attributes_with_proc_defaults.each do |attr|
          # Access the attribute to trigger proc evaluation if needed
          send(attr) if respond_to?(attr) && !style_attribute_initialized?(attr)
        end

        # Trigger evaluation of option proc defaults that haven't been explicitly set
        self.class.option_attributes_with_proc_defaults.each do |attr|
          # Access the attribute to trigger proc evaluation if needed
          send(attr) if respond_to?(attr) && !option_attribute_initialized?(attr)
        end

        super
      end

      # Returns HTML attributes with merged CSS classes.
      #
      # Combines the component's CSS classes (from the `css` method) with any
      # additional classes passed via the `:class` HTML attribute.
      #
      # @return [Hash] HTML attributes with merged class names
      # @example
      #   component = MyComponent.new(class: "custom-class")
      #   component.html_attributes # => { class: "component-base-class custom-class" }
      def html_attributes
        @html_attributes.merge(class: classnames(css, @html_attributes[:class]))
      end

      # Merges multiple class name values into a single string.
      #
      # Uses the configured classname merger (typically Tailwind Merge) to
      # intelligently combine CSS class names, handling conflicts and duplicates.
      #
      # @param classnames [Array<String, nil>] class names to merge
      # @return [String] the merged class names
      # @example
      #   classnames("text-red-500", "text-blue-500") # => "text-blue-500"
      def classnames(*classnames)
        self.class.config.classname_merger.merge(*classnames)
      end

      # Renders the component to an HTML string.
      #
      # Creates a minimal controller and view context to render the component
      # outside of a normal request cycle. Useful for testing and debugging.
      #
      # @return [String] the rendered HTML
      # @example
      #   component = MyComponent.new(color: :primary)
      #   component.to_html # => "<div class=\"...\">...</div>"
      def to_html
        controller = ActionController::Base.new
        controller.request = ActionDispatch::TestRequest.create
        render_in(controller.view_context)
      end
    end
  end
end
