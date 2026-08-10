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
      # builds into ONE HTML::Attributes instance at render, so the
      # Accordion lesson (a plain Hash#merge of two builds clobbers
      # data-controller) holds by construction, not by convention.
      module Declarations
        CONDITION_KEYS = %i[if unless].freeze

        # kind: :register | :value | :action | :target. Values carry
        # source {type: :implicit|:literal|:method, value:}; actions carry
        # on:/at:. conditions is nil or {if:/unless: Symbol|Proc}.
        Entry = Struct.new(:kind, :name, :source, :on, :at, :conditions, keyword_init: true)
        # :entries shadows Enumerable#entries, which Wiring never uses - the
        # member is literally a list of Entry structs, so the natural name wins.
        Wiring = Struct.new(:identifier, :conditions, :entries, keyword_init: true) # rubocop:disable Lint/StructNewOverride
        Element = Struct.new(:name, :extend_inherited, :conditions, :wirings, keyword_init: true)

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

        # A validated cross-controller event name for action `on:` sources
        # ("poetry--core--calendar:change") - ends the hand-written string
        # seam between dispatching and listening controllers.
        def event_name(controller, name)
          identifier = resolve_identifier(controller)
          validate_event!(identifier, Manifest.definition(identifier), name)
          "#{identifier}:#{name}"
        end

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
        def validate_value!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("values", {})&.keys, name, "value")
        end

        def validate_target!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("targets", []), name, "target")
        end

        def validate_action!(identifier, definition, name)
          validate_name!(identifier, definition&.fetch("methods", []), name, "action method")
        end

        def validate_event!(identifier, definition, name)
          known = definition&.fetch("events", nil)
          return if known.nil? || known.include?("#{identifier}:#{name}")

          raise DeclarationError,
                "unknown event #{name.inspect} for #{identifier} - known: #{known.sort.join(", ")}"
        end

        def validate_name!(identifier, known, name, kind)
          return if known.nil?

          js_name = camelize(name)
          return if known.include?(js_name)

          raise DeclarationError,
                "unknown #{kind} #{js_name.inspect} for #{identifier} - " \
                "known #{kind}s: #{known.sort.join(", ")}"
        end

        def camelize(name)
          name.to_s.camelize(:lower)
        end

        # Evaluates one use_stimulus block; #elements is the harvest.
        class RootDSL
          attr_reader :elements

          def initialize(declaring)
            @declaring = declaring
            @elements = []
          end

          def on(name, extend: false, **options, &block)
            name = name.to_sym
            conditions = Declarations.extract_conditions!("#{@declaring} element #{name.inspect}", options)
            element = Element.new(name: name, extend_inherited: extend,
                                  conditions: conditions, wirings: [])
            ElementDSL.new(@declaring, element).instance_exec(&block) if block
            @elements << element
          end

          def event(controller, name) = Declarations.event_name(controller, name)
        end

        # Inside `on :element do ... end`.
        class ElementDSL
          def initialize(declaring, element)
            @declaring = declaring
            @element = element
          end

          def controller(identifier, **options, &block)
            resolved = Declarations.resolve_identifier(identifier)
            conditions = Declarations.extract_conditions!(
              "#{@declaring} controller #{resolved}", options
            )
            wiring = Wiring.new(identifier: resolved, conditions: conditions, entries: [])
            WiringDSL.new(@declaring, wiring).instance_exec(&block) if block
            @element.wirings << wiring
          end

          def event(controller, name) = Declarations.event_name(controller, name)
        end

        # Inside `controller :name do ... end`.
        class WiringDSL
          def initialize(declaring, wiring)
            @declaring = declaring
            @wiring = wiring
            @definition = Manifest.definition(wiring.identifier)
          end

          def register(**options)
            push(kind: :register, options: options)
          end

          # value :open                  -> reads the same-named method/option
          # value :orientation, :horizontal -> literal
          # value :selected, from: :selected_iso -> named method reference
          def value(name, *literal, from: nil, **options)
            if literal.size > 1 || (literal.any? && from)
              raise DeclarationError,
                    "#{context}: value #{name.inspect} takes ONE of a literal or from:"
            end

            Declarations.validate_value!(@wiring.identifier, @definition, name)
            source = if from then { type: :method, value: from.to_sym }
                     elsif literal.any? then { type: :literal, value: literal.first }
                     else { type: :implicit, value: name.to_sym }
                     end
            push(kind: :value, name: name.to_sym, source: source, options: options)
          end

          def action(method, on:, at: nil, **options)
            Declarations.validate_action!(@wiring.identifier, @definition, method)
            push(kind: :action, name: method.to_sym, on: on, at: at, options: options)
          end

          def target(name, **options)
            Declarations.validate_target!(@wiring.identifier, @definition, name)
            push(kind: :target, name: name.to_sym, options: options)
          end

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
