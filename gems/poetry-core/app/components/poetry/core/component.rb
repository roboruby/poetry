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

      # Implementation-detail component classes (a family's inner Item /
      # Group / Sub / Menu classes) inherit the full Component machinery
      # without becoming PUBLISHED components: registry discovery skips
      # internal components, and everything derived from the registry
      # (agent surface, llms, contract gates, docs) follows. Inherited, so
      # a subclass of an internal component stays internal.
      class_attribute :internal_component, default: false, instance_predicate: false

      class << self
        # Marks this class (and its descendants) as an implementation
        # detail - full machinery, no registry entry.
        def internal_component!
          self.internal_component = true
        end
      end

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
        # key: is universal semantic identity (the StableId plan), not an
        # HTML attribute - extracted here so it never renders literally.
        # Not an ActiveModel option (yet): keeping it out of
        # prop_definitions defers the registry/check surface decision to
        # the migration slice.
        @stable_key = attributes[:key] || attributes["key"]
        attributes = attributes.except(:key, "key") if @stable_key

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

      # The caller-supplied semantic identity (key:), if any.
      attr_reader :stable_key

      # The instance-id ladder (the StableId plan): an explicit caller
      # root id wins; a key: derives a stable component-namespaced token
      # (Turbo morph pairs it across renders, cached fragments stay
      # composable); otherwise random - unkeyed components over-replace
      # under morph, they never falsely retain. Call sites memoize
      # (`@instance_id ||=`); this stays pure.
      def poetry_instance_id(prefix)
        explicit = @html_attributes["id"].presence
        return explicit.to_s if explicit

        token = Poetry::Core::StableId.key_token(stable_key)
        return "#{prefix}-#{token}" if token

        sequence = Poetry::Core::StableId.next_sequence_token
        return "#{prefix}-#{sequence}" if sequence

        "#{prefix}-#{SecureRandom.hex(8)}"
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

      # HTML-safe JSON for embedding in a `<script type="application/json">`
      # data island. Escapes the script-terminating characters (`<` `>` `&`,
      # plus the JS line separators U+2028/U+2029) to their JSON `\uXXXX`
      # forms, INDEPENDENT of the host's
      # `ActiveSupport.escape_html_entities_in_json` setting: that flag
      # defaults to true (which escapes them for us) but is host-overridable
      # to false (legitimately, e.g. in API apps), and a component must not
      # depend on a global it neither sets nor checks. `</script>` closes a
      # script element regardless of its `type`, so an unescaped value
      # carrying it would break out of the island into live HTML. Idempotent
      # when the host already escapes (the `\uXXXX` forms carry no literal
      # `<`/`>`/`&`), and JSON.parse decodes the escapes back to the original
      # text. Accepts a pre-serialized JSON string or any `to_json`-able object.
      #
      # @param json [String, Object] serialized JSON, or an object to serialize
      # @return [ActiveSupport::SafeBuffer] escaped, HTML-safe JSON text
      def script_json(json)
        json = json.to_json unless json.is_a?(String)
        json.gsub(/[<>&  ]/) { |char| format('\u%04x', char.ord) }.html_safe
      end

      # Reduces a value to a token safe for a DOM id and a CSS selector:
      # `[A-Za-z0-9_-]` only. A user-controlled id would otherwise break out
      # of the `<style>` block or the id attribute it is interpolated into.
      # Returns nil when nothing safe remains (callers fall back to a random
      # token), preserving the id attribute / JS-selector match by using the
      # same reduced value on both sides.
      #
      # @param value [Object] the requested id
      # @return [String, nil] the safe token, or nil if empty
      def dom_id_token(value)
        value.to_s.gsub(/[^A-Za-z0-9_-]/, "").presence
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
