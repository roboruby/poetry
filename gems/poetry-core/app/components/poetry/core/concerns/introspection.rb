# frozen_string_literal: true

module Poetry
  module Core
    module Concerns
      # The prop-introspection shim: a machine-readable
      # description of a component's public surface - style attributes,
      # options, and slots - derived from the metadata the Styles/Options
      # DSLs and ViewComponent already carry. This is the single source the
      # generated registry, the docs tables, and the MCP prop schema are
      # built from; nothing here is hand-authored.
      module Introspection
        extend ActiveSupport::Concern

        # The registry's marker for a proc default (its value depends on
        # other attributes and is unknowable statically).
        DYNAMIC_DEFAULT = :dynamic
        # The parameter kinds counted toward positional arity.
        POSITIONAL_KINDS = %i[req opt].freeze
        # Parameter kinds that make a keyword surface open or unknowable
        # (**rest accepts anything; a positional can swallow a braceless
        # hash), and the kinds that ARE the keyword surface.
        OPEN_PARAMETER_KINDS = %i[keyrest rest req opt].freeze
        # The parameter kinds that ARE the keyword surface.
        KEYWORD_PARAMETER_KINDS = %i[key keyreq].freeze

        class_methods do
          # The component's full prop surface.
          #
          # @return [Hash] { styles: [...], options: [...], slots: [...] }
          # Documents a slot declared with renders_one/renders_many. The
          # string travels the same road as option/style doc: params - the
          # registry, the agent surface, and the generated API docs. Write
          # it directly above the renders_* declaration it describes.
          #
          # @param name [Symbol] the slot name as declared (plural for
          #   renders_many)
          # @param text [String] one reference-register sentence
          # @return [void]
          #
          # @example
          #   slot_doc :trigger, "The button that opens the dialog."
          #   renders_one :trigger, lambda { |**options, &block| ... }
          def slot_doc(name, text)
            declared_ivar_hash(:@_slot_docs)[name.to_sym] = text
          end

          # The slot_doc strings, hierarchy-wide (nearest wins).
          #
          # @return [Hash{Symbol => String}]
          def slot_docs
            collect_declared_map(:@_slot_docs)
          end

          # The component's full declared surface - styles, options, slots
          # (with descriptions), required slots, and requires_any groups -
          # as the registry generator serializes it.
          #
          # @return [Hash{Symbol => Object}]
          def prop_definitions
            slots = slot_definitions
            {
              styles: style_attributes.map { |name| style_definition(name) },
              options: option_attributes.map { |name| option_definition(name) },
              slots: slots,
              slot_extras: slot_extras,
              required_slots: Introspection.required_slots_surface(self, slots),
              requires_any: Introspection.requires_any_surface(self, slots)
            }
          end

          private

          def style_definition(name)
            definition = { name: name, type: attribute_types[name.to_s].type }
            variants = respond_to?("#{name}_variants") ? public_send("#{name}_variants") : nil
            definition[:variants] = variants if variants.is_a?(Array)
            definition.merge!(default_definition(name, style_attributes_with_static_defaults,
                                                 style_attributes_with_proc_defaults))
            definition[:required] = true if required_attribute?(name)
            doc = style_docs[name.to_sym]
            definition[:description] = doc if doc
            definition
          end

          def option_definition(name)
            definition = { name: name, type: attribute_types[name.to_s].type }
            # An inclusion validator IS the option's enum contract:
            # projecting it makes every enum option statically
            # checkable - select's side:/align:, pagination's
            # current_variant: - through the same value tier style variants
            # already ride. Procs/ranges stay unprojected (unknowable).
            enum = validators_on(name).find { |validator| validator.kind == :inclusion }
                                      &.options&.dig(:in)
            definition[:variants] = enum if enum.is_a?(Array)
            definition.merge!(default_definition(name, option_attributes_with_static_defaults,
                                                 option_attributes_with_proc_defaults))
            definition[:required] = true if required_attribute?(name)
            format = option_format(name)
            definition[:format] = format if format
            doc = option_docs[name.to_sym]
            definition[:description] = doc if doc
            definition
          end

          # ViewComponent's registered slots: renders_one -> one, renders_many
          # -> many (ViewComponent registers the plural name with collection).
          # A typed slot (renders_one :icon, Icon::Component) also carries the
          # slot component's registry path - the machine-readable form of "this
          # slot takes that component's props, not a render block" (an
          # agent can only honor a contract a surface
          # states). Recursion, setter arities, and builder surfaces come from
          # the module-level walker.
          def slot_definitions
            Introspection.slot_surface(self)
          end

          # Hand-rolled with_* conveniences (NavigationMenu#with_link) are
          # part of the consumer call surface even though they are not
          # registered slots.
          def slot_extras
            Introspection.hand_rolled_setters(self, slot_definitions)
          end

          # The default, keyed three ways: a static value (from ActiveModel's
          # default attributes, may legitimately be false), :dynamic for proc
          # defaults (value depends on other attributes), or no key at all.
          def default_definition(name, static_names, proc_names)
            if proc_names.include?(name)
              { default: DYNAMIC_DEFAULT }
            elsif static_names.include?(name)
              { default: _default_attributes[name.to_s]&.value_before_type_cast }
            else
              {}
            end
          end

          def required_attribute?(name)
            validators_on(name).any? { |validator| validator.kind == :presence }
          end
        end

        # The recursive slot walker (composition contracts). Works on
        # ANY slot-owning class - poetry components and their internal
        # builder classes alike (Menubar::Menu is a plain ViewComponent::Base)
        # - so the registry can state the full nested call surface:
        #
        # - types: a polymorphic slot's with_<type> setters
        # - setter_args: max POSITIONAL arity per setter, introspected from
        #   the slot lambda / renderable class (a kwargs-only lambda is 0 -
        #   forecloses `with_item(:item, ...)`, a
        #   type-as-argument convention no setter has)
        # - builders: a class cannot be seen through a wrapping lambda
        #   (`->(**o) { Menu.new(bar: self, **o) }`), so a slot-owning class
        #   declares SLOT_BUILDERS = { setter => BuilderClass } and the
        #   walker recurses into the builder's own surface (cycle-guarded:
        #   sub-in-sub terminates by omission, not loop)
        # - yieldless: a slot lambda that declares &block consumes the
        #   consumer's block itself (poetry convention: capture(&block) with
        #   no arguments), so a block param at the call site is nil at render
        #   (e.g. `menu.with_item do |item|`). A lambda that
        #   stores the block and calls it WITH arguments later (DataTable's
        #   per-row cell renderer) is indistinguishable by signature, so such
        #   a class declares SLOT_BLOCK_YIELDS = { setter => what the block
        #   receives } and the walker exempts those setters
        # - setter_kwargs: the accepted keyword names of a closed-signature
        #   slot lambda (`|classes: nil, &block|`) - any other keyword is an
        #   ArgumentError at render (e.g.
        #   `with_item(class:)`). Open signatures (**rest), positional-hash
        #   signatures, and class renderables (kwargs ride the attributes
        #   hash) are unknowable-or-open and stay unemitted.
        # - required_content: a lambda cannot be seen raising "requires a
        #   content block" (Carousel with_item), so a slot-owning class
        #   declares SLOT_REQUIRED_CONTENT = { setter => hint } (the
        #   SLOT_BUILDERS pattern) and the registry states the requirement
        # - required_slots: a before_render raise ("Menubar menu requires
        #   with_trigger" - an omission every other
        #   check passes silently) cannot be introspected, so a slot-owning class
        #   declares REQUIRED_SLOTS = { setter => hint } and the registry
        #   states which setters a call cannot omit. Keys must resolve to a
        #   declared setter (name / singular / type) - an unresolvable key
        #   fails registry generation rather than shipping a rule no
        #   template could ever satisfy. Only declared where satisfaction
        #   is exactly derivable: a requirement satisfiable through a
        #   hand-rolled alias (NavigationMenu's with_item-or-with_link)
        #   stays undeclared - a false "missing slot" on a legitimate
        #   template is worse than a silent gap.
        # - requires_any: the conditional any-of contracts no
        #   single-fact rule can state (Button's
        #   "content OR icon slot OR loading:", Command's "id OR
        #   aria-label"). A class declares REQUIRES_ANY = [{ hint:,
        #   content: true, slots: [...], options: [...] }, ...] mirroring
        #   its before_render predicate; a call satisfying NO listed
        #   alternative fails poetry check statically. Slot names must
        #   resolve; each group needs a hint and at least one alternative.
        # - SLOT_RENDERS = { setter => ComponentClass }: a lambda-wrapped
        #   slot that purely forwards **options/&block to one component
        #   (Toast's with_action -> Button) hides that component from
        #   introspection exactly like SLOT_BUILDERS hides builder classes
        #   - the declaration restores the slot's "component" fact so the
        #   whole typed-slot rule family (option values, requires_content,
        #   requires_any) applies to its callers. Declare ONLY pure
        #   forwarders - a lambda that intercepts caller keys would make
        #   the projected contract a lie.
        class << self
          # The registry-shaped slot contracts of one slot-owning class -
          # see the walker notes above for every emitted key.
          #
          # @param klass [Class] a component or builder class
          # @param seen [Array<Class>] the recursion guard
          # @return [Array<Hash>]
          # @raise [Poetry::Core::Error] when a SLOT_RENDERS entry is not a
          #   poetry component class
          def slot_surface(klass, seen: [])
            return [] unless klass.respond_to?(:registered_slots)

            builders = declared_builders(klass)
            required_content = declared_required_content(klass)
            block_yields = declared_constant(klass, :SLOT_BLOCK_YIELDS)
            renders = declared_constant(klass, :SLOT_RENDERS)
            slot_docs = klass.respond_to?(:slot_docs) ? klass.slot_docs : {}
            klass.registered_slots.map do |slot_name, config|
              definition = { name: slot_name, many: config[:collection] == true }
              doc = slot_docs[slot_name.to_sym]
              definition[:description] = doc if doc
              renderable = config[:renderable]
              definition[:component] = renderable.component_path if renderable.respond_to?(:component_path)
              # A declared pure-forwarding lambda (SLOT_RENDERS) restores
              # the component fact a wrapping lambda hides.
              # Polymorphic slots stay out - their types are their contract.
              if config[:renderable_hash].nil? &&
                 (declared = renders[slot_setters(slot_name, config).first&.to_sym])
                unless declared.respond_to?(:component_path)
                  raise Poetry::Core::Error,
                        "#{klass}::SLOT_RENDERS[#{slot_name}] must be a poetry component class"
                end

                definition[:component] ||= declared.component_path
              end
              definition[:types] = config[:renderable_hash].keys if config[:renderable_hash]
              setter_args = setter_positional_args(slot_name, config)
              definition[:setter_args] = setter_args unless setter_args.empty?
              setter_kwargs = setter_keyword_args(slot_name, config)
              definition[:setter_kwargs] = setter_kwargs unless setter_kwargs.empty?
              yieldless = yieldless_setters(slot_name, config) - block_yields.keys
              definition[:yieldless] = yieldless unless yieldless.empty?
              required = required_content.slice(*slot_setters(slot_name, config).map(&:to_sym))
              definition[:required_content] = required unless required.empty?
              surfaces = builder_surfaces(slot_name, config, builders, seen + [klass])
              definition[:builders] = surfaces unless surfaces.empty?
              definition
            end
          end

          # The validated REQUIRED_SLOTS declaration of a slot-owning class:
          # each key must name a setter the given slot definitions actually
          # generate (the slot itself, a collection's singular, or a
          # polymorphic type).
          #
          # @param klass [Class] the slot-owning class
          # @param definitions [Array<Hash>] the class's {slot_surface}
          # @return [Hash{String => String}] setter name => hint
          # @raise [Poetry::Core::Error] for a key matching no slot setter
          def required_slots_surface(klass, definitions)
            declared_constant(klass, :REQUIRED_SLOTS).to_h do |key, hint|
              name = key.to_s
              unless definitions.any? { |slot| resolves_setter?(slot, name) }
                raise Poetry::Core::Error,
                      "#{klass}::REQUIRED_SLOTS key #{key.inspect} matches no slot setter"
              end

              [name, hint]
            end
          end

          # The validated REQUIRES_ANY declaration: each group needs
          # a hint plus at least one alternative, and slot alternatives must
          # name setters the definitions actually generate.
          #
          # @param klass [Class] the slot-owning class
          # @param definitions [Array<Hash>] the class's {slot_surface}
          # @return [Array<Hash>] one normalized group per declaration
          #   (hint, plus content/slots/options as declared)
          # @raise [Poetry::Core::Error] for a group without a hint or an
          #   alternative, or a slot matching no slot setter
          def requires_any_surface(klass, definitions)
            declared_constant(klass, :REQUIRES_ANY).map do |group|
              group = group.transform_keys(&:to_s)
              slots = (group["slots"] || []).map(&:to_s)
              options = (group["options"] || []).map(&:to_s)
              unless group["hint"] && (group["content"] || slots.any? || options.any?)
                raise Poetry::Core::Error,
                      "#{klass}::REQUIRES_ANY group needs a hint and at least one alternative"
              end

              slots.each do |name|
                next if definitions.any? { |slot| resolves_setter?(slot, name) }

                raise Poetry::Core::Error,
                      "#{klass}::REQUIRES_ANY slot #{name.inspect} matches no slot setter"
              end
              emitted = { "hint" => group["hint"] }
              emitted["content"] = true if group["content"]
              emitted["slots"] = slots if slots.any?
              emitted["options"] = options if options.any?
              emitted
            end
          end

          # Every own with_* method that is neither a slot-generated setter
          # (with_<name>/<singular>/<type> and their _content twins) nor
          # inherited - NavigationMenu#with_link, PieChart's with_py.
          #
          # @param klass [Class] the slot-owning class
          # @param definitions [Array<Hash>] the class's {slot_surface}
          # @return [Array<String>] the setter names without their with_
          #   prefix, sorted
          def hand_rolled_setters(klass, definitions)
            generated = definitions.flat_map do |slot|
              names = [slot[:name].to_s]
              names << slot[:name].to_s.delete_suffix("s") if slot[:many]
              names.concat((slot[:types] || []).map(&:to_s))
              names
            end
            klass.public_instance_methods(false).map(&:to_s)
                 .select { |method| method.start_with?("with_") }
                 .reject { |method| method.end_with?("_content") }
                 .map { |method| method.delete_prefix("with_") }
                 .sort - generated
          end

          private

          def declared_builders(klass)
            declared_constant(klass, :SLOT_BUILDERS)
          end

          def declared_required_content(klass)
            declared_constant(klass, :SLOT_REQUIRED_CONTENT)
          end

          def declared_constant(klass, name)
            klass.const_defined?(name) ? klass.const_get(name) : {}
          rescue NameError
            {}
          end

          # Does a slot definition generate this setter name? Mirrors the
          # checker's slot_entry resolution: exact name, a collection's
          # singular, or a polymorphic type.
          def resolves_setter?(slot, name)
            slot[:name].to_s == name ||
              (slot[:many] && slot[:name].to_s == "#{name}s") ||
              (slot[:types] || []).map(&:to_s).include?(name)
          end

          # The per-item setter suffixes a slot generates (the plural batch
          # setter of a collection has a different shape and is not tracked).
          def slot_setters(slot_name, config)
            return config[:renderable_hash].keys.map(&:to_s) if config[:renderable_hash]

            name = slot_name.to_s
            [config[:collection] ? name.delete_suffix("s") : name]
          end

          def setter_positional_args(slot_name, config)
            if (types = config[:renderable_hash])
              types.filter_map do |type, definition|
                arity = positional_arity(definition[:renderable_function] || definition[:renderable])
                [type, arity] if arity
              end.to_h
            else
              setter = slot_setters(slot_name, config).first
              arity = positional_arity(config[:renderable_function] || config[:renderable])
              arity ? { setter.to_sym => arity } : {}
            end
          end

          def setter_keyword_args(slot_name, config)
            if (types = config[:renderable_hash])
              types.filter_map do |type, definition|
                names = keyword_names(definition[:renderable_function] || definition[:renderable])
                [type, names] if names
              end.to_h
            else
              setter = slot_setters(slot_name, config).first
              names = keyword_names(config[:renderable_function] || config[:renderable])
              names ? { setter.to_sym => names } : {}
            end
          end

          def yieldless_setters(slot_name, config)
            if (types = config[:renderable_hash])
              types.filter_map do |type, definition|
                type if consumes_block?(definition[:renderable_function] || definition[:renderable])
              end
            elsif consumes_block?(config[:renderable_function] || config[:renderable])
              slot_setters(slot_name, config).map(&:to_sym)
            else
              []
            end
          end

          # The closed keyword surface of a slot lambda, or nil when open or
          # unknowable: class renderables take kwargs through the attributes
          # hash, and a lambda with no keywords at all has nothing to
          # enumerate.
          def keyword_names(callable)
            return nil if callable.is_a?(Class) || !callable.respond_to?(:parameters)

            parameters = callable.parameters
            return nil if parameters.any? { |kind, _name| OPEN_PARAMETER_KINDS.include?(kind) }

            names = parameters.filter_map { |kind, name| name.to_s if KEYWORD_PARAMETER_KINDS.include?(kind) }
            names.empty? ? nil : names
          end

          # A lambda declaring &block takes the consumer's block for itself -
          # ViewComponent never renders it against a component, so a block
          # param at the call site can only be nil. Class renderables and
          # block-less lambdas returning components DO yield (render_in
          # yields the component instance).
          def consumes_block?(callable)
            !callable.is_a?(Class) && callable.respond_to?(:parameters) &&
              callable.parameters.any? { |kind, _name| kind == :block }
          end

          # Max positional argument count, or nil when unknowable (no
          # callable, or a *rest signature).
          def positional_arity(callable)
            parameters =
              if callable.is_a?(Class)
                callable.instance_method(:initialize).parameters
              elsif callable.respond_to?(:parameters)
                callable.parameters
              end
            return nil unless parameters
            return nil if parameters.any? { |kind, _name| kind == :rest }

            parameters.count { |kind, _name| POSITIONAL_KINDS.include?(kind) }
          rescue NameError
            nil
          end

          def builder_surfaces(slot_name, config, builders, seen)
            slot_setters(slot_name, config).filter_map do |setter|
              builder = builders[setter.to_sym]
              next if builder.nil? || seen.include?(builder)

              slots = slot_surface(builder, seen: seen)
              extras = hand_rolled_setters(builder, slots)
              next if slots.empty? && extras.empty?

              surface = { slots: slots }
              surface[:slot_extras] = extras unless extras.empty?
              required = required_slots_surface(builder, slots)
              surface[:required_slots] = required unless required.empty?
              [setter.to_sym, surface]
            end.to_h
          end
        end
      end
    end
  end
end
