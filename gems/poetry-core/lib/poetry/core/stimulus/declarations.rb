# frozen_string_literal: true

module Poetry
  module Core
    module Stimulus
      # The use_stimulus declaration model (the DSL behind
      # Concerns::Stimulus). Declarations build at class-load time and are
      # validated against the controllers manifest THERE - an unknown
      # controller, value, action method, target, or event name raises at
      # boot/test-collection instead of first render. The Builder still
      # guards emission for wiring built outside declarations.
      #
      # Element-major by design: every controller wired to one element
      # builds into ONE HTML::Attributes instance at render, so a plain
      # Hash#merge of two builds can never clobber data-controller -
      # correct by construction, not by convention.
      #
      # See {Poetry::Core::Concerns::Stimulus} for the component-facing
      # contract and a full declaration example.
      #
      # @example A use_stimulus declaration (class body of a component)
      #   use_stimulus do
      #     on :root do
      #       controller :hover_card do
      #         register
      #         value :open
      #       end
      #     end
      #     on :trigger do
      #       controller :hover_card do
      #         action :pointer_enter, on: :pointerenter
      #       end
      #       controller :popper do
      #         target :anchor
      #       end
      #     end
      #   end
      module Declarations
        # The condition keywords every DSL call accepts.
        CONDITION_KEYS = %i[if unless].freeze

        # kind: :register | :value | :action | :target. Values carry
        # source {type: :implicit|:literal|:method, value:}; actions carry
        # on:/at:. conditions is nil or {if:/unless: Symbol|Proc}.
        Entry = Struct.new(:kind, :name, :source, :on, :at, :conditions, keyword_init: true)
        # :entries shadows Enumerable#entries, which Wiring never uses - the
        # member is literally a list of Entry structs, so the natural name wins.
        Wiring = Struct.new(:identifier, :conditions, :entries, keyword_init: true) # rubocop:disable Lint/StructNewOverride
        # One declared element (:root or a named part) and the per-controller
        # wirings attached to it.
        Element = Struct.new(:name, :extend_inherited, :conditions, :wirings, keyword_init: true)

        # Raised at class load for an invalid or manifest-unknown
        # declaration.
        class DeclarationError < Poetry::Core::Error; end

        module_function

        # Symbols resolve against the manifest by unique suffix
        # (:hover_card -> "poetry--core--hover-card"), so declarations
        # never hand-write gem namespaces; strings and arrays pass through
        # the Builder's existing policy (strict for poetry--*, unvalidated
        # for host-app controllers).
        def resolve_identifier(identifier)
          return Builder.format_identifier(identifier) unless identifier.is_a?(Symbol)

          dashed = identifier.to_s.tr("_", "-")
          catalog = Manifest.catalog.keys
          return dashed if catalog.include?(dashed)

          matches = catalog.select { |key| key.end_with?("--#{dashed}") }
          case matches.size
          when 1 then matches.first
          when 0
            raise DeclarationError,
                  "unknown stimulus controller #{identifier.inspect} - known: " \
                  "#{catalog.sort.join(", ")}. Pass a String for a host-app controller."
          else
            raise DeclarationError,
                  "ambiguous stimulus controller #{identifier.inspect}: " \
                  "#{matches.sort.join(", ")} - use the full identifier"
          end
        end

        # A validated cross-controller event name for action `on:` sources,
        # resolved to the manifest's REAL emitted name ("poetry:calendar:change";
        # layer controllers keep the identifier prefix) - ends the hand-written
        # string seam between dispatching and listening controllers.
        #
        # @param controller [Symbol, String] the dispatching controller
        # @param name [Symbol, String] the event's short name (the suffix
        #   after the final colon)
        # @return [String] the full emitted event name
        # @example
        #   event(:calendar, :change) # => "poetry:calendar:change"
        def event_name(controller, name)
          identifier = resolve_identifier(controller)
          known = Manifest.definition(identifier)&.fetch("events", nil)
          return "#{identifier}:#{name}" if known.nil?

          matches = known.select { |event| event.end_with?(":#{name}") }
          return matches.first if matches.length == 1

          if matches.length > 1
            raise DeclarationError,
                  "ambiguous event #{name.inspect} for #{identifier} " \
                  "(#{matches.sort.join(", ")}) - use the full event string"
          end
          raise DeclarationError,
                "unknown event #{name.inspect} for #{identifier} - known: #{known.sort.join(", ")}"
        end

        # Validates and returns the if:/unless: conditions of a DSL call.
        #
        # @api private
        def extract_conditions!(context, options)
          return nil if options.empty?

          unknown = options.keys - CONDITION_KEYS
          if unknown.any?
            raise DeclarationError,
                  "#{context}: unknown option(s) #{unknown.map(&:inspect).join(", ")} - " \
                  "allowed: if:, unless:"
          end
          options.each do |key, condition|
            next if condition.is_a?(Symbol) || condition.is_a?(Proc)

            raise DeclarationError, "#{context}: #{key}: must be a Symbol or Proc"
          end
          options
        end

        # Name validations mirror the Builder's render-time checks, moved
        # to declaration time. A nil definition (host controller) skips.
        #
        # @api private
        def validate_value!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("values", {})&.keys, name, "value")
        end

        # @api private
        def validate_target!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("targets", []), name, "target")
        end

        # @api private
        def validate_action!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("methods", []), name, "action method")
        end

        # @api private
        def validate_name!(identifier, known, name, kind)
          return if known.nil?

          js_name = camelize(name)
          return if known.include?(js_name)

          raise DeclarationError,
                "unknown #{kind} #{js_name.inspect} for #{identifier} - " \
                "known #{kind}s: #{known.sort.join(", ")}"
        end

        # The declared Ruby name in its JS (lowerCamel) spelling.
        #
        # @api private
        def camelize(name)
          name.to_s.camelize(:lower)
        end

        # Registry-shaped serialization of one resolved element (plain
        # string keys, YAML round-trippable) - the element-level projection
        # consumers read: the registry, skill text, and the docs wiring
        # tables. Conditions serialize as possibility-space: the predicate
        # name for symbols, "conditional" for procs.
        #
        # @api private
        def serialize_element(element)
          definition = { "element" => element.name.to_s }
          if (label = condition_label(element.conditions))
            definition["conditional"] = label
          end
          definition["controllers"] = element.wirings.map { |wiring| serialize_wiring(wiring) }
          definition
        end

        # @api private
        def serialize_wiring(wiring)
          serialized = { "identifier" => wiring.identifier }
          if (label = condition_label(wiring.conditions))
            serialized["conditional"] = label
          end
          wiring.entries.each do |entry|
            case entry.kind
            when :register
              serialized["registers"] = condition_label(entry.conditions) || true
            when :value
              (serialized["values"] ||= []) << serialize_entry(entry, "name" => entry.name.to_s)
            when :action
              action = { "method" => camelize(entry.name) }
              action["on"] = serialize_on(entry.on) unless entry.on.nil?
              action["at"] = entry.at.to_s if entry.at
              (serialized["actions"] ||= []) << serialize_entry(entry, action)
            when :target
              (serialized["targets"] ||= []) << serialize_entry(entry, "name" => camelize(entry.name))
            end
          end
          serialized
        end

        # @api private
        def serialize_entry(entry, base)
          if (label = condition_label(entry.conditions))
            base["conditional"] = label
          end
          base
        end

        # @api private
        def serialize_on(on)
          on.is_a?(Array) ? on.map(&:to_s) : on.to_s
        end

        # The serialized label of a conditions hash, or nil when
        # unconditional.
        #
        # @api private
        def condition_label(conditions)
          return nil if conditions.nil? || conditions.empty?

          conditions.filter_map do |key, condition|
            condition.is_a?(Symbol) ? "#{key} #{condition}" : key.to_s
          end.join(", ").presence || "conditional"
        end

        # Evaluates one use_stimulus block; #elements is the harvest. The
        # block's vocabulary is {#on} (declare an element) and {#event}
        # (build a validated event name).
        class RootDSL
          attr_reader :elements

          def initialize(declaring)
            @declaring = declaring
            @elements = []
          end

          # Declares the wiring of one element of the component's anatomy.
          # `:root` is the component root; other names match the element
          # keys templates read back through `stimulus_attributes_for`.
          # Redeclaring an element in a subclass replaces it wholesale
          # unless `extend: true` merges into the inherited wiring.
          #
          # @param name [Symbol, String] the element to wire (:root, :trigger, ...)
          # @param extend [Boolean] merge into the inherited element instead
          #   of replacing it
          # @param options [Hash] if:/unless: conditions (Symbol predicate or Proc)
          # @yield evaluates the block as an {ElementDSL} for this element
          # @example
          #   on :trigger do
          #     controller :popper do
          #       target :anchor
          #     end
          #   end
          def on(name, extend: false, **options, &block)
            name = name.to_sym
            conditions = Declarations.extract_conditions!("#{@declaring} element #{name.inspect}", options)
            element = Element.new(name: name, extend_inherited: extend,
                                  conditions: conditions, wirings: [])
            ElementDSL.new(@declaring, element).instance_exec(&block) if block
            @elements << element
          end

          # A validated cross-controller event name - see
          # {Declarations.event_name}.
          def event(controller, name) = Declarations.event_name(controller, name)
        end

        # Inside `on :element do ... end`: {#controller} attaches one
        # controller's wiring to the element.
        class ElementDSL
          def initialize(declaring, element)
            @declaring = declaring
            @element = element
          end

          # Wires one Stimulus controller to this element.
          #
          # @param identifier [Symbol, String, Array] a Symbol resolves
          #   against the controllers manifest by unique suffix
          #   (:hover_card); pass a String for a host-app controller
          # @param options [Hash] if:/unless: conditions (Symbol predicate or Proc)
          # @yield evaluates the block as a {WiringDSL} for this controller
          def controller(identifier, **options, &block)
            resolved = Declarations.resolve_identifier(identifier)
            conditions = Declarations.extract_conditions!(
              "#{@declaring} controller #{resolved}", options
            )
            wiring = Wiring.new(identifier: resolved, conditions: conditions, entries: [])
            WiringDSL.new(@declaring, wiring).instance_exec(&block) if block
            @element.wirings << wiring
          end

          # A validated cross-controller event name - see
          # {Declarations.event_name}.
          def event(controller, name) = Declarations.event_name(controller, name)
        end

        # Inside `controller :name do ... end`: the wiring vocabulary.
        # {#register} boots the controller on the element; {#value},
        # {#action}, and {#target} declare the data attributes the render
        # emits - each name validated against the controllers manifest at
        # class load.
        class WiringDSL
          def initialize(declaring, wiring)
            @declaring = declaring
            @wiring = wiring
            @definition = Manifest.definition(wiring.identifier)
          end

          # Emits the controller's identifier into this element's
          # data-controller - a controller instance boots here. Value,
          # action, and target entries alone never register a controller.
          #
          # @param options [Hash] if:/unless: conditions (Symbol predicate or Proc)
          def register(**options)
            push(kind: :register, options: options)
          end

          # value :open                  -> reads the same-named method/option
          # value :orientation, :horizontal -> literal
          # value :selected, from: :selected_iso -> named method reference
          def value(name, *literal, from: nil, **options)
            if literal.size > 1 || (!literal.empty? && from)
              raise DeclarationError,
                    "#{context}: value #{name.inspect} takes ONE of a literal or from:"
            end

            Declarations.validate_value!(@wiring.identifier, @definition, name)
            # literal presence is arity-detected, so `value :x, false` and
            # `value :x, nil` stay literals (never .any?, which is false
            # for [false]).
            source = if from then { type: :method, value: from.to_sym }
                     elsif !literal.empty? then { type: :literal, value: literal.first }
                     else { type: :implicit, value: name.to_sym }
                     end
            push(kind: :value, name: name.to_sym, source: source, options: options)
          end

          # on: nil declares a BARE descriptor (Stimulus element-default
          # event - the forwarding shape: "poetry--core--x#method").
          def action(method, on: nil, at: nil, **options)
            Declarations.validate_action!(@wiring.identifier, @definition, method)
            push(kind: :action, name: method.to_sym, on: on, at: at, options: options)
          end

          # Marks this element as one of the controller's named targets.
          #
          # @param name [Symbol] the target name (validated against the
          #   controllers manifest; declared snake_case, emitted lowerCamel)
          # @param options [Hash] if:/unless: conditions (Symbol predicate or Proc)
          def target(name, **options)
            Declarations.validate_target!(@wiring.identifier, @definition, name)
            push(kind: :target, name: name.to_sym, options: options)
          end

          # A validated cross-controller event name - see
          # {Declarations.event_name}.
          def event(controller, name) = Declarations.event_name(controller, name)

          private

          def context = "#{@declaring} controller #{@wiring.identifier}"

          def push(kind:, options:, name: nil, source: nil, on: nil, at: nil)
            conditions = Declarations.extract_conditions!("#{context} #{kind}", options)
            @wiring.entries << Entry.new(kind: kind, name: name, source: source,
                                         on: on, at: at, conditions: conditions)
          end
        end
      end
    end
  end
end
