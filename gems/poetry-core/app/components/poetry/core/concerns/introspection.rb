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

        DYNAMIC_DEFAULT = :dynamic
        POSITIONAL_KINDS = %i[req opt].freeze

        class_methods do
          # The component's full prop surface.
          #
          # @return [Hash] { styles: [...], options: [...], slots: [...] }
          def prop_definitions
            {
              styles: style_attributes.map { |name| style_definition(name) },
              options: option_attributes.map { |name| option_definition(name) },
              slots: slot_definitions,
              slot_extras: slot_extras
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
            definition
          end

          def option_definition(name)
            definition = { name: name, type: attribute_types[name.to_s].type }
            # An inclusion validator IS the option's enum contract (Blocks
            # v1.1): projecting it makes every enum option statically
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
            definition
          end

          # ViewComponent's registered slots: renders_one -> one, renders_many
          # -> many (ViewComponent registers the plural name with collection).
          # A typed slot (renders_one :icon, Icon::Component) also carries the
          # slot component's registry path - the machine-readable form of "this
          # slot takes that component's props, not a render block" (the W2
          # alert crash class: an agent can only honor a contract a surface
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
        #   the menu crash class: `with_item(:item, ...)` guessed a
        #   type-as-argument convention no setter has)
        # - builders: a class cannot be seen through a wrapping lambda
        #   (`->(**o) { Menu.new(bar: self, **o) }`), so a slot-owning class
        #   declares SLOT_BUILDERS = { setter => BuilderClass } and the
        #   walker recurses into the builder's own surface (cycle-guarded:
        #   sub-in-sub terminates by omission, not loop)
        class << self
          def slot_surface(klass, seen: [])
            return [] unless klass.respond_to?(:registered_slots)

            builders = declared_builders(klass)
            klass.registered_slots.map do |slot_name, config|
              definition = { name: slot_name, many: config[:collection] == true }
              renderable = config[:renderable]
              definition[:component] = renderable.component_path if renderable.respond_to?(:component_path)
              definition[:types] = config[:renderable_hash].keys if config[:renderable_hash]
              setter_args = setter_positional_args(slot_name, config)
              definition[:setter_args] = setter_args unless setter_args.empty?
              surfaces = builder_surfaces(slot_name, config, builders, seen + [klass])
              definition[:builders] = surfaces unless surfaces.empty?
              definition
            end
          end

          # Every own with_* method that is neither a slot-generated setter
          # (with_<name>/<singular>/<type> and their _content twins) nor
          # inherited - NavigationMenu#with_link, PieChart's with_py.
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
            klass.const_defined?(:SLOT_BUILDERS) ? klass.const_get(:SLOT_BUILDERS) : {}
          rescue NameError
            {}
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
              [setter.to_sym, surface]
            end.to_h
          end
        end
      end
    end
  end
end
