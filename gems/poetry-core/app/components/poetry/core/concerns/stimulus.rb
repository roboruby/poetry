# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The use_stimulus contract: a class-level, element-major declaration
      # of the component's Stimulus wiring, replacing both the hand-rolled
      # `<element>_stimulus_attributes` methods and the previous
      # `stimulated_with` DSL (controller-major, root-only - it could not
      # express multi-element wiring, and no component ever adopted it).
      #
      #   use_stimulus do
      #     on :root do
      #       controller :hover_card do
      #         register
      #         value :open
      #         value :open_delay, unless: -> { open_delay.nil? }
      #       end
      #       controller :popper do
      #         register
      #         value :side
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
      #
      # Render side: `stimulus_attributes_for(:trigger)` returns the
      # element's merged attribute hash (public - templates and slot
      # lambdas call it directly); `stimulus_action(:open)` /
      # `stimulus_event(:change)` build validated descriptor strings for
      # forwarding; `stimulus_attributes(:a, :b) { |a, b| ... }` is the
      # escape hatch for wiring too dynamic to declare - every builder
      # shares ONE Attributes instance, so multi-controller merges are
      # correct by construction.
      #
      # Declarations validate against the controllers manifest at CLASS
      # LOAD (unknown controller/value/action/target/event raises at boot,
      # not first render) and are declared once per element: a subclass
      # redeclaring an element REPLACES it wholesale (the Ruby-override
      # intuition; Sheet/Drawer re-controller their roots this way), while
      # `on :root, extend: true` merges into the inherited element
      # (date_field -> time_field adds values). Untouched elements inherit.
      module Stimulus
        extend ActiveSupport::Concern

        class_methods do
          # Declares (part of) the component's stimulus wiring. Multiple
          # blocks compose additively within a class; shared wiring modules
          # call this from their `included` hook.
          #
          # @yield evaluates the block as a
          #   {Poetry::Core::Stimulus::Declarations::RootDSL}:
          #   `on :element do controller :name do ... end end`
          # @return [void]
          # @raise [ArgumentError] without a block
          def use_stimulus(&block)
            raise ArgumentError, "use_stimulus requires a block" unless block

            dsl = Poetry::Core::Stimulus::Declarations::RootDSL.new(name || to_s)
            dsl.instance_exec(&block)
            dsl.elements.each { |element| store_stimulus_element(element) }
          end

          # This class's own declarations, element name -> Element.
          #
          # @return [Hash{Symbol => Poetry::Core::Stimulus::Declarations::Element}]
          def own_stimulus_elements
            @own_stimulus_elements ||= {}
          end

          # The effective wiring after inheritance: walk the superclass
          # chain root-first, folding each class's declarations over the
          # inherited set - redeclared elements replace wholesale unless
          # declared with extend: true, which appends to the inherited
          # element's wirings.
          #
          # @return [Hash{Symbol => Poetry::Core::Stimulus::Declarations::Element}]
          def stimulus_elements
            chain = []
            klass = self
            while klass.respond_to?(:own_stimulus_elements)
              chain.unshift(klass)
              klass = klass.superclass
            end

            chain.each_with_object({}) do |ancestor, resolved|
              ancestor.own_stimulus_elements.each do |name, element|
                resolved[name] =
                  if element.extend_inherited && resolved[name]
                    Poetry::Core::Stimulus::Declarations::Element.new(
                      name: name, extend_inherited: false, conditions: element.conditions,
                      wirings: resolved[name].wirings + element.wirings
                    )
                  else
                    element
                  end
              end
            end
          end

          # Every controller identifier declared anywhere on the class, in
          # declaration order - the search space for unqualified
          # stimulus_action / stimulus_event resolution.
          #
          # @return [Array<String>]
          def stimulus_identifiers
            stimulus_elements.values.flat_map { |element| element.wirings.map(&:identifier) }.uniq
          end

          # Resolves a declaration-style identifier (Symbol suffix, String,
          # or Array) to its full manifest identifier - see
          # {Poetry::Core::Stimulus::Declarations.resolve_identifier}.
          #
          # @param identifier [Symbol, String, Array] the declaration-style identifier
          # @return [String] the full Stimulus identifier
          def resolve_stimulus_identifier(identifier)
            Poetry::Core::Stimulus::Declarations.resolve_identifier(identifier)
          end

          # The registry-shaped projection of the RESOLVED wiring (post-
          # inheritance, so Sheet publishes sheet controllers) - plain data
          # for the registry, skill text, and docs tables.
          #
          # @return [Array<Hash>] one serialized element per declared element
          def stimulus_definitions
            stimulus_elements.values.map do |element|
              Poetry::Core::Stimulus::Declarations.serialize_element(element)
            end
          end

          # Descriptor builders are STATIC facts of the declarations, so
          # they exist at class level - helpers, generator templates, and
          # test selectors consume them without an instance. on:/at: build
          # the evented token ("click->id#method"); without on: the bare
          # descriptor (element-default event).
          #
          # @param args [Array<Symbol, String>] `(method)` resolves the method
          #   across the declared controllers; `(controller, method)` pins one
          # @param on [Symbol, String, Array<Symbol>, nil] the event(s) to listen for
          # @param at [Symbol, String, nil] the event target (:window, :document)
          # @return [String] the action descriptor ("click->poetry--core--x#open")
          def stimulus_action(*args, on: nil, at: nil)
            controller, method = unpack_stimulus_descriptor_args(args, :action)
            identifier = resolve_stimulus_descriptor(controller, method, kind: :action)
            Poetry::Core::Stimulus::Builder.new(identifier, Poetry::Core::HTML::Attributes.new)
                                           .action(method, on: on, at: at)
          end

          # A validated event-name string for listening markup;
          # stimulus_event(:change) resolves across the declared
          # controllers, stimulus_event(:controller, :change) pins one.
          #
          # @param args [Array<Symbol, String>] `(name)` or `(controller, name)`
          # @return [String] the full event name
          def stimulus_event(*args)
            controller, name = unpack_stimulus_descriptor_args(args, :event)
            identifier = resolve_stimulus_descriptor(controller, name, kind: :event)
            Poetry::Core::Stimulus::Declarations.event_name(identifier, name)
          end

          private

          def unpack_stimulus_descriptor_args(args, kind)
            case args.size
            when 1 then [nil, args.first]
            when 2 then args
            else
              raise ArgumentError,
                    "stimulus_#{kind}(#{kind}) or stimulus_#{kind}(:controller, #{kind})"
            end
          end

          def resolve_stimulus_descriptor(controller, name, kind:)
            return resolve_stimulus_identifier(controller) if controller

            identifiers = stimulus_identifiers
            if identifiers.empty?
              raise ArgumentError,
                    "no use_stimulus declarations on #{self} - pass the controller: " \
                    "stimulus_#{kind}(:controller, #{name.inspect})"
            end
            return identifiers.first if identifiers.size == 1

            matches = identifiers.select { |id| stimulus_descriptor_match?(id, name, kind) }
            return matches.first if matches.size == 1

            raise ArgumentError,
                  "#{matches.empty? ? "no declared controller defines" : "ambiguous"} " \
                  "#{kind} #{name.inspect} (declared: #{identifiers.join(", ")}) - qualify: " \
                  "stimulus_#{kind}(:controller, #{name.inspect})"
          end

          def stimulus_descriptor_match?(identifier, name, kind)
            definition = Poetry::Core::Stimulus::Manifest.definition(identifier)
            return false unless definition

            case kind
            when :action
              definition.fetch("methods", []).include?(Poetry::Core::Stimulus::Declarations.camelize(name))
            when :event
              # Real emitted names (poetry:<component>:<event> for component
              # events; identifier-prefixed for layer events) - match by the
              # ":<name>" suffix, the same rule event_name resolves by.
              definition.fetch("events", []).any? { |event| event.end_with?(":#{name}") }
            end
          end

          def store_stimulus_element(element)
            existing = own_stimulus_elements[element.name]
            own_stimulus_elements[element.name] =
              if existing
                Poetry::Core::Stimulus::Declarations::Element.new(
                  name: element.name,
                  extend_inherited: existing.extend_inherited || element.extend_inherited,
                  conditions: element.conditions || existing.conditions,
                  wirings: existing.wirings + element.wirings
                )
              else
                element
              end
          end
        end

        # The declared wiring for one element as a plain attributes hash,
        # ready to merge into the element's tag or forward as component
        # kwargs. Public by design - templates call it, ending the
        # `public :inner_stimulus_attributes` juggling.
        #
        # @param element_name [Symbol, String] a declared element (:root, ...)
        # @return [Hash] the element's data attributes; empty when the
        #   element's if:/unless: conditions do not hold
        # @raise [ArgumentError] for an element no use_stimulus block declared
        def stimulus_attributes_for(element_name)
          element = self.class.stimulus_elements[element_name.to_sym]
          unless element
            known = self.class.stimulus_elements.keys
            raise ArgumentError,
                  "undeclared stimulus element #{element_name.inspect} on #{self.class}" \
                  "#{known.any? ? " - declared: #{known.join(", ")}" : " (no use_stimulus declarations)"}"
          end
          return {} unless stimulus_conditions_met?(element.conditions)

          attrs = Poetry::Core::HTML::Attributes.new
          element.wirings.each do |wiring|
            next unless stimulus_conditions_met?(wiring.conditions)

            builder = Poetry::Core::Stimulus::Builder.new(wiring.identifier, attrs)
            wiring.entries.each do |entry|
              apply_stimulus_entry(builder, entry) if stimulus_conditions_met?(entry.conditions)
            end
          end
          # The agent-tool registrar rides the root's shared Attributes
          # instance (Concerns::AgentTools) - a per-instance opt-in.
          apply_webmcp_wiring(attrs) if element_name.to_sym == :root && respond_to?(:apply_webmcp_wiring)
          attrs.to_attributes
        end

        # The escape hatch for wiring too dynamic to declare: yields one
        # Builder per controller, all sharing ONE Attributes instance.
        # Controllers resolve like declarations (Symbol -> manifest,
        # String/Array -> verbatim).
        #
        # @param controllers [Array<Symbol, String, Array>] one or more
        #   controller identifiers
        # @yield [*builders] one {Poetry::Core::Stimulus::Builder} per
        #   controller, in order
        # @return [Hash] the accumulated attributes
        # @raise [ArgumentError] with no controllers
        def stimulus_attributes(*controllers)
          raise ArgumentError, "stimulus_attributes needs at least one controller" if controllers.empty?

          attrs = Poetry::Core::HTML::Attributes.new
          builders = controllers.map do |controller|
            Poetry::Core::Stimulus::Builder.new(
              self.class.resolve_stimulus_identifier(controller), attrs
            )
          end
          yield(*builders) if block_given?
          attrs.to_attributes
        end

        # Delegates to the class-level builder (descriptors are static
        # facts of the declarations); stimulus_action(:open) resolves
        # across declared controllers, on:/at: build the evented token.
        #
        # @param on [Symbol, String, Array<Symbol>, nil] the event(s) to listen for
        # @param at [Symbol, String, nil] the event target (:window, :document)
        # @return [String] the action descriptor
        def stimulus_action(*, on: nil, at: nil)
          self.class.stimulus_action(*, on: on, at: at)
        end

        # Delegates to the class-level builder: stimulus_event(:change)
        # resolves across the declared controllers,
        # stimulus_event(:controller, :change) pins one.
        #
        # @return [String] the full event name
        def stimulus_event(*)
          self.class.stimulus_event(*)
        end

        # Replays one declared Entry onto the element's attribute builder.
        #
        # @api private
        def apply_stimulus_entry(builder, entry)
          case entry.kind
          when :register then builder.register_controller
          when :value then builder.with_value(entry.name, stimulus_value_for(entry))
          when :action then builder.with_action(entry.name, on: entry.on, at: entry.at)
          when :target then builder.with_target(entry.name)
          end
        end

        # The rendered value of a declared value entry: the literal, or the
        # named/implicit method's return.
        #
        # @api private
        def stimulus_value_for(entry)
          source = entry.source
          case source[:type]
          when :literal then source[:value]
          else send(source[:value])
          end
        end

        # Whether a declaration's if:/unless: conditions hold for this
        # instance; nil conditions always hold.
        #
        # @param conditions [Hash{Symbol => Symbol, Proc}, nil] the if:/unless: pair
        # @return [Boolean]
        # @api private
        def stimulus_conditions_met?(conditions)
          return true if conditions.nil?

          if (condition = conditions[:if]) && !evaluate_stimulus_condition(condition)
            return false
          end
          if (condition = conditions[:unless]) && evaluate_stimulus_condition(condition)
            return false
          end

          true
        end

        # Evaluates one if:/unless: condition in instance context.
        #
        # @api private
        def evaluate_stimulus_condition(condition)
          condition.is_a?(Proc) ? instance_exec(&condition) : send(condition)
        end

        private :apply_stimulus_entry, :stimulus_value_for, :stimulus_conditions_met?, :evaluate_stimulus_condition
      end
    end
  end
end
