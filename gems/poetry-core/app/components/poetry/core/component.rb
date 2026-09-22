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
      include Poetry::Core::Contrib::WrappedHelper
      include Poetry::Core::Concerns::Styles
      include Poetry::Core::Concerns::Options
      include Poetry::Core::Concerns::Stimulus
      include Poetry::Core::Concerns::Introspection
      include Poetry::Core::Concerns::Parts
      include Poetry::Core::Concerns::AgentTools

      # Implementation-detail component classes (a family's inner Item /
      # Group / Sub / Menu classes) inherit the full Component machinery
      # without becoming PUBLISHED components: registry discovery skips
      # internal components, and everything derived from the registry
      # (agent surface, llms, contract gates, docs) follows. Inherited, so
      # a subclass of an internal component stays internal.
      class_attribute :internal_component, default: false, instance_predicate: false

      # The declared vocabulary the runtime values tier checks:
      # name => { variants: [...] or nil, required: true/false }, recorded
      # by `style` and `option` at declaration (copy-on-write per class, so
      # a subclass's declarations never leak up). A direct lookup, not an
      # ActiveModel validation pass - measured at nine percent of a
      # Button's render when it ran through `valid?`.
      class_attribute :declared_values, instance_accessor: false, default: {}.freeze

      # The caller-supplied semantic identity (key:), if any.
      #
      # @return [Object, nil]
      attr_reader :stable_key

      class << self
        # Marks this class (and its descendants) as an implementation
        # detail - full machinery, no registry entry.
        #
        # @example An inner class of a component family
        #   class DropdownMenu::Item::Component < Poetry::Core::Component
        #     internal_component!
        #   end
        # @return [void]
        def internal_component!
          self.internal_component = true
        end

        # The vocabulary the runtime values tier checks, computed once per
        # class at first construction (the class body is complete by then):
        # the recorded `style`/`option` declarations plus every inclusion
        # validator with an Array (`validates :side, inclusion: { in: SIDES }`
        # is how options declare a closed vocabulary). Method validators are
        # not vocabulary and stay the component's own (Icon's unknown-name
        # policy).
        #
        # @return [Hash{Symbol => Hash}]
        # @api private
        def runtime_vocabulary
          @runtime_vocabulary ||= begin
            vocabulary = declared_values.dup
            names = attribute_names.map(&:to_sym)
            validators.each do |validator|
              next unless validator.is_a?(ActiveModel::Validations::InclusionValidator)
              next unless (allowed = validator.options[:in]).is_a?(Array)

              validator.attributes.each do |attribute|
                attribute = attribute.to_sym
                next unless names.include?(attribute)

                spec = vocabulary[attribute] || { variants: nil, required: false }
                # A style declared open (no variants) stays open: an inherited
                # inclusion validator from a parent's closed declaration never
                # narrows it again.
                next if spec[:open]

                vocabulary[attribute] = spec.merge(variants: allowed).freeze unless spec[:variants]
              end
            end
            vocabulary.freeze
          end
        end

        # Records a declared attribute's vocabulary for the runtime values
        # tier ({#guard_declared_values}).
        #
        # @param name [Symbol]
        # @param variants [Array, nil] the closed vocabulary, nil for open values
        # @param required [Boolean]
        # @param open [Boolean] a style redeclared without variants: any value passes,
        #   the vocabulary is not enforced
        # @return [void]
        def record_declared_value(name, variants:, required:, open: false)
          spec = { variants: variants, required: required, open: open }.freeze
          self.declared_values = declared_values.merge(name.to_sym => spec).freeze
        end

        # Names the view helper that renders this component - for a
        # component the host application (or an engine) defines on the
        # DSL. The poetry-core engine defines the method on Action View at
        # boot and on every reload, and the app's registry carries the name
        # so `poetry check`, llms.txt and the generated skill know the
        # helper. Own-class only: a subclass declares its own or has none.
        # The gems' components do not declare one; their helpers follow the
        # `poetry_<name>` convention.
        #
        # @example
        #   class Demo::Badge::Component < Poetry::Core::Component
        #     helper :demo_badge
        #   end
        #   # <%= demo_badge(tone: :loud) { "New" } %>
        # @param name [Symbol, String] a Ruby method name
        # @return [void]
        # @raise [ArgumentError] when the name is not a plain method name
        def helper(name)
          name = name.to_s
          unless name.match?(/\A[a-z_][a-z0-9_]*\z/)
            raise ArgumentError, "helper name #{name.inspect} must be a plain method name (a-z, 0-9, _)"
          end

          @helper_name = name
        end

        # The declared helper name, or nil (the gems' components; a
        # subclass that declares none).
        #
        # @return [String, nil]
        attr_reader :helper_name
      end

      class << self
        # The current Poetry::Core configuration - a shortcut to
        # {Poetry::Core::Config.current} for components and their templates.
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
        # statically.
        #
        # @param hint [String] what the content block is, for the error message
        # @return [void]
        # @example
        #   class Avatar::Component < Poetry::Core::Component
        #     requires_content "the initials fallback"
        #   end
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

      # Keywords that are never options and never typos - the passthrough
      # vocabulary the static check exempts too (Check::Catalog::PASSTHROUGH).
      PASSTHROUGH_KEYS = %w[class id key webmcp identity data aria role style].freeze

      # HTML attribute names a caller passes through on purpose. Exempt from
      # the near-miss guard so `for:` never reads as a typo of a `form`
      # option, `size:` on a component without a size axis stays the native
      # attribute, and so on. Only keys that are NOT declared options reach
      # the guard, so a declared option of the same name is untouched.
      HTML_ATTRIBUTE_KEYS = %w[
        accept accesskey action alt autocapitalize autocomplete autofocus checked cite cols colspan
        contenteditable crossorigin datetime decoding dir dirname disabled download draggable enctype
        enterkeyhint for form headers height hidden href hreflang inert inputmode is itemid itemprop
        itemref itemscope itemtype label lang list loading max maxlength method min minlength multiple
        name nonce novalidate open part pattern ping placeholder popover readonly referrerpolicy rel
        required reversed rows rowspan scope selected size sizes slot span spellcheck src srcset start
        step tabindex target title translate type value width wrap
      ].freeze

      # The self-identification markup contract, the convention every
      # component follows: `data-component` on the component root maps live DOM
      # back to the component that rendered it - the hook agents, the
      # Verifier, and the browser-verification loop key on.
      #
      # A component rendering as another's root passes identity: (the
      # composition seam), and the root wears that name instead.
      #
      # @return [Hash] e.g. { "data-component" => "button" }
      def component_data_attributes
        { "data-component" => (@identity || self.class.component_title).to_s }
      end

      # `data-slot` for a named part of the component's anatomy
      # (skeleton parts carry their role: icon, label, spinner, ...).
      #
      # @param part [Symbol, String] the anatomy part name
      # @return [Hash] e.g. { "data-slot" => "icon" }
      def slot_data_attributes(part)
        { "data-slot" => part.to_s }
      end

      # The root element's attributes, ready to splat: the caller's
      # {#html_attributes} (its classes already merged with the dictionary's)
      # over the component's own root markup - `data-slot` (the component
      # title, or the one in +extra+), `data-component`, and the root's
      # Stimulus wiring when a `use_stimulus` block declares `:root`. The
      # caller's attributes win: a class, id or data-* passed in is kept and
      # the component's default fills the gaps.
      #
      # A component adds its own root markup by overriding and passing it up;
      # the template splats the result.
      #
      # @example A component's override
      #   def root_attributes
      #     super("role" => "status", "data-variant" => variant)
      #   end
      # @example The template
      #   <%= tag.div(**root_attributes) do %>
      #
      # @param extra [Hash] the component's own root attributes; a
      #   `"data-slot"` here replaces the default
      # @return [Hash] the root's attributes, flat (`data-x`, `aria-x`,
      #   booleans as the attribute name), for `tag` and `content_tag`
      def root_attributes(extra = {})
        own = { "data-slot" => root_slot }.merge(extra).merge(component_data_attributes)
        wired = self.class.stimulus_elements.key?(:root) ? :root : nil
        html_attributes.merge_if_not_set(element_markup(own, stimulus: wired)).to_attributes
      end

      # The root's `data-slot`: the component title in kebab form (a
      # ToggleGroup roots as "toggle-group").
      #
      # @return [String] the slot name
      def root_slot
        self.class.component_title.to_s.tr("_", "-")
      end

      # A part's attributes, ready to splat. Named after a part, it carries
      # the part's `data-slot` (the root slot and the part name: a
      # DropdownMenu's `:content` is "dropdown-menu-content"), the
      # dictionary's classes for it (`css(part)`, when the Style declares the
      # element), and the part's Stimulus wiring when a `use_stimulus` block
      # declares an element of that name - each of which the markup may
      # override (its own `"data-slot"` or `"class"` wins; `stimulus:` names
      # another element, or `false` for none). The wiring merges beneath the
      # markup the safe way: plain `Hash#merge` drops one side's
      # `data-controller` or `data-action` when both carry one, and this
      # concatenates them. Rendered more than once (a row, an addon), the
      # builder takes its arguments and the part stays the same.
      #
      # @example A part builder, and its template
      #   def content_attributes
      #     attrs = { "id" => content_id, "role" => "menu" }
      #     attrs["hidden"] = true unless open
      #     element_attributes(:content, attrs)
      #   end
      #   # <%= tag.div(**content_attributes) do %>
      #
      # @param part [Symbol, String, nil] the part; nil (or a Hash in its
      #   place) for markup with no part of its own
      # @param attrs [Hash] the element's markup, in braces after a part
      # @param stimulus [Symbol, String, false, nil] the `use_stimulus`
      #   element whose wiring joins the markup: nil takes the part's own when
      #   one is declared, false takes none
      # @return [Hash] the element's attributes, flat, for `tag` and `content_tag`
      def element_attributes(part = nil, attrs = {}, stimulus: nil)
        if part.is_a?(Hash)
          attrs = part
          part = nil
        end
        own = attrs
        if part
          own = { "data-slot" => "#{root_slot}-#{part.to_s.tr("_", "-")}", "class" => css(part) }.compact.merge(attrs)
          stimulus = part.to_sym if stimulus.nil? && self.class.stimulus_elements.key?(part.to_sym)
        end
        element_markup(own, stimulus: stimulus || nil).to_attributes
      end

      # The merge-aware form of an element's markup with its wiring.
      #
      # @param attrs [Hash] the element's markup
      # @param stimulus [Symbol, String, nil] a declared element, or nil
      # @return [Poetry::Core::HTML::Attributes]
      def element_markup(attrs, stimulus:)
        attributes = Poetry::Core::HTML::Attributes.new(attrs)
        stimulus ? attributes.merge(stimulus_attributes_for(stimulus)) : attributes
      end
      private :element_markup

      # Enforces the class-level requires_content declaration - call from
      # before_render. The message is built from the declaration so the
      # runtime raise and the registry's static contract can never disagree.
      #
      # @return [void]
      # @raise [ArgumentError] when the component was called without a
      #   content block
      def ensure_content!
        return if content?

        raise ArgumentError, "#{self.class.component_module.demodulize} requires a content block " \
                             "(#{self.class.required_content})"
      end

      # ViewComponent's render_in, with the content block wrapped once so
      # #content can read what the block RETURNED - capture keeps only what
      # the block wrote to the buffer, and a scalar return vanishes there.
      #
      # @param view_context [ActionView::Base] the rendering view
      # @return [ActiveSupport::SafeBuffer] the rendered component
      def render_in(view_context, **)
        @content_guarded = false
        remove_instance_variable(:@content_return) if defined?(@content_return)
        return super unless block_given?

        recorded = proc { |*args| @content_return = yield(*args) }
        super(view_context, **, &recorded)
      end

      # The captured content block, guarded once per render: a block that
      # returned a scalar (a number, a symbol, a boolean) while writing
      # nothing to the buffer captures as nothing at all - `poetry_badge {
      # count }` renders an empty badge - so a requires_content component
      # raises in development and test naming the value and the fix, and
      # logs everywhere else; a component without the declaration logs. A
      # block that wrote to the buffer, returned a String, returned nil,
      # returned a collection (an empty loop's each) or composed slots
      # (its last call a with_* setter, which returns the slot or the
      # component) is fine.
      #
      # @return [ActiveSupport::SafeBuffer, nil] the captured content
      def content
        captured = super
        guard_content_return(captured) unless @content_guarded
        captured
      end

      # The content-return guard behind #content.
      #
      # @param captured [ActiveSupport::SafeBuffer, nil] what capture kept
      # @return [void]
      # @raise [ArgumentError] a scalar return on a requires_content
      #   component, in development and test
      def guard_content_return(captured)
        @content_guarded = true
        return unless defined?(@content_return)

        value = @content_return
        return if value.nil? || value.is_a?(::String) || value.respond_to?(:each) || captured.present?
        return if value.is_a?(ViewComponent::Base) || value.is_a?(ViewComponent::Slot)

        message = "#{passthrough_owner} content block returned #{value.inspect.truncate(60)} (#{value.class}), " \
                  "which captures as nothing - return a String (call to_s on it) or write it with <%= %>"
        raise ArgumentError, message if strict_passthrough? && self.class.required_content

        Rails.logger&.warn("poetry: #{message}") if defined?(Rails) && Rails.respond_to?(:logger)
      end
      private :guard_content_return

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
        # key: is universal semantic identity, not an HTML attribute -
        # extracted here so it never renders literally. Not an ActiveModel
        # option (yet): keeping it out of prop_definitions defers the
        # registry/check surface decision to a later migration.
        @stable_key = attributes[:key] || attributes["key"]
        attributes = attributes.except(:key, "key") if @stable_key

        # webmcp: is the per-instance opt-in of the agent-tool contract
        # (Concerns::AgentTools) - universal like key:, never an HTML
        # attribute; the root's Stimulus wiring carries the registration.
        @webmcp = attributes[:webmcp] || attributes["webmcp"]
        attributes = attributes.except(:webmcp, "webmcp") unless @webmcp.nil?

        # identity: is the composition seam for a component that renders AS
        # another component's root (ToastTrigger renders as a Button): the
        # inner root wears the outer's data-component. Universal like key:,
        # never an HTML attribute - and the ONLY sanctioned way to set
        # data-component (the raw attribute is reserved, see guard_passthrough).
        @identity = attributes[:identity] || attributes["identity"]
        attributes = attributes.except(:identity, "identity") unless @identity.nil?

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
        given = attributes.with_indifferent_access
        names = attribute_names
        @html_attributes = Poetry::Core::HTML::Attributes.new(guard_passthrough(given.except(*names)))
        # The root merges classes with the kit's merger (its CSS mode's).
        @html_attributes.classname_merger = classname_merger

        assign_attributes given.slice(*names)
        guard_declared_values
      end

      # The passthrough contract, enforced at the seam. A keyword that is not
      # an option renders as an HTML attribute on the root (title:, tabindex:,
      # colspan:) - so a NEAR-MISS of a declared option (varient:) would
      # silently render a bogus attribute while the default applied. That
      # raises in development and test with the did-you-mean the static check
      # gives, and only logs in production (the render still succeeds).
      # data-component is the component's own identity - the hook agents,
      # the Verifier and the browser loop key on - and is never overridable:
      # dropped in production, raised the same way in development and test.
      # data-slot is NOT reserved: re-slotting an embedded root is the
      # composition seam a part contract allows; re-identifying one goes
      # through identity:, the sanctioned spelling.
      #
      # @param html_attrs [ActiveSupport::HashWithIndifferentAccess]
      # @return [ActiveSupport::HashWithIndifferentAccess] the attributes, minus a reserved override
      def guard_passthrough(html_attrs)
        problems = []

        if html_attrs.key?("data-component")
          problems << "data-component is #{passthrough_owner}'s own identity attribute and is never overridable"
          html_attrs = html_attrs.except("data-component")
        end
        data = html_attrs["data"]
        if data.respond_to?(:key?) && data.key?("component")
          problems << "data: { component: } is #{passthrough_owner}'s own identity attribute and is never overridable"
          html_attrs["data"] = data.except("component")
        end

        html_attrs.each_key do |key|
          next if PASSTHROUGH_KEYS.include?(key) || HTML_ATTRIBUTE_KEYS.include?(key) || key.include?("-")

          suggestion = option_suggestion(key)
          next unless suggestion

          problems << "#{passthrough_owner} has no option #{key}: (did you mean #{suggestion}:?) - " \
                      "unknown keywords render as HTML attributes"
        end
        return html_attrs if problems.empty?

        raise ArgumentError, problems.join("; ") if strict_passthrough?

        Rails.logger&.warn("poetry: #{problems.join("; ")}") if defined?(Rails) && Rails.respond_to?(:logger)
        html_attrs
      end

      # The did-you-mean against this component's declared options and
      # styles, the same checker the static check runs.
      def option_suggestion(key)
        require "did_you_mean"
        DidYouMean::SpellChecker.new(dictionary: self.class.attribute_names.map(&:to_s)).correct(key.to_s).first
      end

      # The component named in a passthrough problem - an anonymous class
      # (a test double) has no path to title.
      def passthrough_owner
        self.class.name ? self.class.component_title : "this component"
      end

      # The runtime values tier, beside the passthrough guard: the declared
      # vocabulary (`style ... variants:`, `required:`) is checked at
      # construction, where every component - gem or app, whatever it does
      # in before_render - passes. Off-list values raise in development and
      # test with the allowed values and a did-you-mean; in production they
      # log and render as before. `poetry check` catches the same mistakes
      # in templates statically; this tier catches the value that arrives
      # from data. A direct lookup over {.declared_values}; a component's
      # custom validators keep their own policy.
      def guard_declared_values
        problems = nil
        self.class.runtime_vocabulary.each do |name, spec|
          value = public_send(name)
          if value.nil? || (value.respond_to?(:empty?) && value.empty?)
            (problems ||= []) << "#{passthrough_owner} requires #{name}:" if spec[:required]
          elsif spec[:variants] && !spec[:variants].include?(value)
            (problems ||= []) << off_list_problem(name, value, spec[:variants])
          end
        end
        return unless problems

        message = problems.join("; ")
        raise ArgumentError, message if strict_passthrough?

        Rails.logger&.warn("poetry: #{message}") if defined?(Rails) && Rails.respond_to?(:logger)
      end

      # The message a developer reads for an off-list value: the declared
      # vocabulary and a did-you-mean.
      def off_list_problem(name, value, allowed)
        "#{passthrough_owner} #{name}: #{value.inspect} is not one of " \
          "#{allowed.map(&:inspect).join(", ")}#{variant_suggestion(value, allowed)}"
      end

      # The did-you-mean suffix for an off-list value, or an empty string.
      def variant_suggestion(value, allowed)
        return "" if allowed.empty? || value.nil?

        require "did_you_mean"
        suggestion = DidYouMean::SpellChecker.new(dictionary: allowed.map(&:to_s)).correct(value.to_s).first
        suggestion ? " (did you mean #{suggestion.to_sym.inspect}?)" : ""
      end

      # Raise (development, test) or log (everything else).
      def strict_passthrough?
        defined?(Rails) && Rails.respond_to?(:env) && Rails.env.local?
      end

      private :guard_passthrough, :option_suggestion, :passthrough_owner, :strict_passthrough?,
              :guard_declared_values, :off_list_problem, :variant_suggestion

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
        # Set, never merge: Attributes#merge folds a class through the merger
        # against the caller's original, so every non-utility token the caller
        # passed (a cn-* hook) came out twice. The resolved string already
        # carries the caller's classes once, where they win conflicts.
        attributes = @html_attributes.deep_dup
        attributes[:class] = classnames(css, @html_attributes[:class])
        attributes
      end

      # The instance-id ladder: an explicit caller root id wins; a key:
      # derives a stable component-namespaced token (Turbo morph pairs it
      # across renders, cached fragments stay composable); otherwise
      # random - unkeyed components over-replace under morph, they never
      # falsely retain. Call sites memoize (`@instance_id ||=`); this
      # stays pure.
      #
      # @param prefix [String] the component-namespaced id prefix
      # @return [String] the resolved DOM id
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
      # Uses the kit's classname merger (Tailwind Merge in :tailwind mode,
      # the BEM merger in :bem mode - {Poetry::Core::CSS::Modes.merger_for})
      # to combine CSS class names, handling conflicts and duplicates.
      #
      # @param classnames [Array<String, nil>] class names to merge
      # @return [String] the merged class names
      # @example
      #   classnames("text-red-500", "text-blue-500") # => "text-blue-500"
      def classnames(*classnames)
        classname_merger.merge(*classnames)
      end

      # The class-name merger this component merges with: the one that
      # matches its CSS mode ({Poetry::Core::CSS::Modes.merger_for}).
      #
      # @return [#merge]
      def classname_merger
        Poetry::Core::CSS::Modes.merger_for(css_mode)
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

      private_class_method :record_declared_value
    end
  end
end
